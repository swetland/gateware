// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <strings.h>
#include <string.h>

typedef unsigned u32;
typedef unsigned short u16;

char *append(char *buf, const char *s) {
	while (*s)
		*buf++ = *s++;
	return buf;
}
char *append_u16(char *buf, unsigned n) {
	sprintf(buf, "%04x", n & 0xFFFF);
	return buf + strlen(buf);
}
char *append_int(char *buf, int n) {
	sprintf(buf, "%d", n);
	return buf + strlen(buf);
}

const char *regname[] = {
	"R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7",
};

const char *alufunc[] = {
	"AND", "ORR", "XOR", "NOT", "ADD", "SUB", "SLT", "SLU",
	"SHL", "SHR", "ROL", "ROR", "MUL", "DUP", "SWP", "MHI",
};

void printinst(char *buf, unsigned pc, unsigned instr, const char *fmt, unsigned verbose) {
	char *start = buf;
	char note[64];
	note[0] = 0;

	unsigned c = (instr >> 3) & 7;
	unsigned a = (instr >> 6) & 7;
	unsigned b = (instr >> 9) & 7;
	unsigned f = (instr >> 12) & 15;

	// immediates
	int s7 = (instr >> 9) & 0x3F;
	int s9 = ((instr >> 9) & 0x3F) | (instr & 0xC0);
	int s10 = ((instr >> 9) & 0x3F) | (instr & 0x1C0);
	int s12 = ((instr >> 9) & 0x3F) | (instr & 0x1C0) | ((instr & 0x30) << 5);
	unsigned u6 = ((instr >> 6) & 0x7) | ((instr >> 9) & 0x38);

	// sign-extend
	if (instr & 0x8000) {
		s7 |= 0xFFFFFF80;
		s9 |= 0xFFFFFF00;
		s10 |= 0xFFFFFE00;
		s12 |= 0xFFFFF800;
	}

	while (*fmt) {
		if (*fmt != '@') {
			*buf++ = *fmt++;
			continue;
		}
		switch (*++fmt) {
		case 'A':
			buf = append(buf, regname[a]);
			break;
		case 'B':
			buf = append(buf, regname[b]);
			break;
		case 'C':
			buf = append(buf, regname[c]);
			break;
		case 'F':
			buf = append(buf, alufunc[f]);
			break;
		case '7': // si7
			buf = append_u16(buf, s7);
			sprintf(note, "(%d)", s7);
			break;
		case '9': // si9 (pcrel)
			buf = append_u16(buf, pc + s9 + 1);
			sprintf(note, "(%d)", pc + s9 + 1);
			break;
		case '0': // si10
			buf = append_u16(buf, s10);
			sprintf(note, "(%d)", s10);
			break;
		case '2': // si12 (pcrel)
			buf = append_u16(buf, pc + s12 + 1);
			sprintf(note, "(%d)", pc + s12 + 1);
			break;
		case 'h': // only used by mhi
			buf = append_u16(buf, s7 & 0x3F);
			sprintf(note, "(%d)", s7 & 0x3F);
			break;
		case 'u': // only used by LC/SC
			buf = append_u16(buf, u6);
			sprintf(note, "(%d)", u6);
		case 0:
			goto done;
		}
		fmt++;
	}
done:
	if (verbose && note[0]) {
		while ((buf - start) < 22) *buf++ = ' ';
		strcpy(buf, note);
		buf += strlen(note);
	}
	*buf = 0;
}

struct {
	u16 mask;
	u16 value;
	const char *fmt;
} decode[] = {
	{ 0b1111000000000111, 0b0011000000000000, "NOT @C, @A" },
	{ 0b1111111111000111, 0b0000000000000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000001001000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000010010000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000011011000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000100100000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000101101000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000110110000000, "MOV @C, @A" },
	{ 0b1111111111000111, 0b0000111111000000, "MOV @C, @A" },
	{ 0b0000000000000111, 0b0000000000000000, "@F @C, @A, @B" },
	{ 0b0000000000000111, 0b0000000000000001, "ADD @C, @A, @7" },
	{ 0b0000000000000111, 0b0000000000000010, "MOV @C, @0" },
	{ 0b0000000000000111, 0b0000000000000011, "LW @C, [@A, @7]" },
	{ 0b0000000100000111, 0b0000000000000100, "BNZ @C, @9" },
	{ 0b0000000100000111, 0b0000000100000100, "BZ @C, @9" },
	{ 0b0000000000000111, 0b0000000000000101, "SW @C, [@A, @7]" },
	{ 0b0000000000001111, 0b0000000000000110, "B @2" },
	{ 0b0000000000001111, 0b0000000000001110, "BL @2" },
	{ 0b1000111000001111, 0b0000000000000111, "B @A" },
	{ 0b1000111000001111, 0b0000000000001111, "BL @A" },
	{ 0b1000111000000111, 0b0000001000000111, "NOP" },
	{ 0b1000111000000111, 0b0000010000000111, "RSV0" },
	{ 0b1000111000000111, 0b0000011000000111, "RSV1" },
	{ 0b1000111000000111, 0b0000100000000111, "LC @c, @6" },
	{ 0b1000111000000111, 0b0000101000000111, "SC @c, @6" },
	{ 0b1111111000000111, 0b0000110000000111, "SHL @C, @A, 1" },
	{ 0b1111111000000111, 0b0001110000000111, "SHR @C, @A, 1" },
	{ 0b1111111000000111, 0b0010110000000111, "ROL @C, @A, 1" },
	{ 0b1111111000000111, 0b0011110000000111, "ROR @C, @A, 1" },
	{ 0b1111111000000111, 0b0000111000000111, "SHL @C, @A, 4" },
	{ 0b1111111000000111, 0b0001111000000111, "SHR @C, @A, 4" },
	{ 0b1111111000000111, 0b0010111000000111, "ROL @C, @A, 4" },
	{ 0b1111111000000111, 0b0011111000000111, "ROR @C, @A, 4" },
	{ 0b1000000000000111, 0b1000000000000111, "MHI @C, @A, @h" },
	{ 0b0000000000000000, 0b0000000000000000, "UND" },
};

static void disassemble0(char *buf, unsigned pc, unsigned instr, unsigned verbose) {
	int n = 0;
	for (n = 0 ;; n++) {
		if ((instr & decode[n].mask) == decode[n].value) {
			printinst(buf, pc, instr, decode[n].fmt, verbose);
			return;
		}
	}
	buf[0] = 0;
}

void disassemble(char *buf, unsigned pc, unsigned instr) {
	disassemble0(buf, pc, instr, 1);
}

#ifdef STANDALONE
int main(int argc, char **argv) {
        char buf[256];
        char line[1024];
        while (fgets(line, 1024, stdin)) {
                unsigned insn = 0xFFFF;
		unsigned pc = 0;
                sscanf(line, "%04x%04x", &insn, &pc);
                disassemble0(buf, pc, insn, 0);
                printf("%s\n", buf);
                fflush(stdout);
        }
        return 0;
}
#endif
