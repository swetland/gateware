// Copyright 2015, Brian Swetland <swetland@frotz.net>
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
	"R8", "R9", "R10", "R11", "R12", "SP", "LR", "R15",
};

const char *alufunc[] = {
	"MOV", "AND", "ORR", "XOR", "ADD", "SUB", "MUL", "MHI",
	"SLT", "SLE", "SHR", "SHL", "BIS", "BIC", "TBS", "BIT",
};

void printinst(char *buf, unsigned pc, unsigned instr, const char *fmt) {
	unsigned a = (instr >> 4) & 15;
	unsigned b = (instr >> 8) & 15;
	unsigned fhi = (instr >> 12) & 15;
	unsigned flo = (instr >> 8) & 15;
	unsigned i8 = (instr >> 8);
	unsigned i4 = (instr >> 12);
	unsigned i12 = (instr >> 4);
	int s4 = (i4 & 0x8) ? (i4 | 0xFFFFFFF0) : (i4 & 0xF);
	int s8 = (i8 & 0x80) ? (i8 | 0xFFFFFF00) : (i8 & 0xFF);
	int s12 = (i12 & 0x800) ? (i12 | 0xFFFFF800) : (i12 & 0xFFF);

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
			buf = append(buf, regname[instr & 3]);
			break;
		case 'F':
			buf = append(buf, alufunc[fhi]);
			break;
		case 'f': // alt alu func
			buf = append(buf, alufunc[flo]);
			break;
		case '4':
			buf = append_int(buf, s4);
			break;
		case '8':
			buf = append_int(buf, s8);
			break;
		case 's':
			buf = append_int(buf, s12);
			break;
		case 0:
			goto done;
		}
		fmt++;
	}
done:
	*buf = 0;
}

struct {
	u16 mask;
	u16 value;
	const char *fmt;
} decode[] = {
	{ 0b0000000000001111, 0b0000000000000000, "MOV @A, @8" },
	{ 0b0000000000001111, 0b0000000000000001, "MHI @A, @8" },
	{ 0b1111000000001111, 0b0000000000000010, "MOV @A, @B" },
	{ 0b0000000000001111, 0b0000000000000010, "@F @A, @B" },
	{ 0b0000111100001111, 0b0000000000000011, "MOV @A, @4" },
	{ 0b0000000000001111, 0b0000000000000011, "@f @A, @4" },
	{ 0b1111000000001100, 0b0000000000000100, "MOV @C, @B" },
	{ 0b0000000000001100, 0b0000000000000100, "@F @C, @B, @A" },
	{ 0b0000000000001111, 0b0000000000001000, "LW @A, [@B, @4]" },
	{ 0b0000000000001111, 0b0000000000001001, "SW @A, [@B, @4]" },
	{ 0b0000000000001111, 0b0000000000001010, "BNZ @A, @8" },
	{ 0b0000000000001111, 0b0000000000001011, "BZ @A, @8" },
	{ 0b0000000000001111, 0b0000000000001100, "B @s" },
	{ 0b0000000000001111, 0b0000000000001101, "BL @s" },
	{ 0b1111000000001111, 0b0000000000001110, "B @B" },
	{ 0b1111000000001111, 0b0001000000001110, "BL @B" },
	{ 0b1111000000001111, 0b0010000000001110, "NOP" },
	{ 0b0000000000000000, 0b0000000000000000, "UNDEFINED" },
};

void disassemble(char *buf, unsigned pc, unsigned instr) {
	int n = 0;
	for (n = 0 ;; n++) {
		if ((instr & decode[n].mask) == decode[n].value) {
			printinst(buf, pc, instr, decode[n].fmt);
			return;
		}
	}
	buf[0] = 0;
}

#ifdef STANDALONE
int main(int argc, char **argv) {
        char buf[256];
        char line[1024];
        while (fgets(line, 1024, stdin)) {
                unsigned insn = 0xFFFF;
                sscanf(line, "%x", &insn);
                disassemble(buf, 0, insn);
                printf("%s\n", buf);
                fflush(stdout);
        }
        return 0;
}
#endif
