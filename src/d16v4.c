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
	"ADD", "SUB", "AND", "ORR", "XOR", "SLT", "SGE", "MUL",
};

void printinst(char *buf, unsigned pc, unsigned instr, const char *fmt,
	       unsigned _ex, unsigned ev, unsigned verbose) {
	unsigned tmp;
	char *start = buf;
	char note[64];
	note[0] = 0;

	unsigned a = (instr >> 7) & 7;
	unsigned b = (instr >> 10) & 7;
	unsigned c = (instr >> 4) & 7;
	unsigned fhi = (instr >> 13) & 7;
	unsigned flo = instr & 7;

	// immediate sub-fields
	unsigned s = (instr >> 15);
	unsigned i = (instr >> 10) & 0x1F;
	unsigned j = (instr >> 4) & 0x3F;
	unsigned k = (instr >> 7) & 7;
	unsigned m = (instr >> 6) & 1;

	// immediates
	int s6 = i;
	int s7 = i | (m << 5);
	int s9 = i | (k << 5);
	int s11 = i | ((j & 0x1F) << 5);
	int s12 = i | (j << 5);

	// sign-extend
	if (s) {
		s6 |= 0xFFFFFFE0;
		s7 |= 0xFFFFFFC0;
		s9 |= 0xFFFFFF00;
		s11 |= 0xFFFFFC00;
		s12 |= 0xFFFFF800;
	}

	while (*fmt) {
		unsigned ex;
		if (*fmt == '+') {
			ex = _ex;
			fmt++;
		} else {
			ex = 0;
		}
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
			buf = append(buf, alufunc[fhi]);
			break;
		case 'f': // alt alu func
			buf = append(buf, alufunc[flo]);
			break;
		case '6':
			if (ex) {
				tmp = (ev << 4) | (s6 & 15);
				if (tmp & 0x8000) tmp |= 0xFFFF0000;
			} else {
				tmp = s6;
			}
			buf = append_u16(buf, tmp);
			sprintf(note, "(%d)", tmp);
			break;
		case '7':
			buf = append_u16(buf, pc + s7 + 1);
			sprintf(note, "(%d)", pc + s7 + 1);
			break;
		case '9':
			if (ex) {
				tmp = (ev << 4) | (s9 & 15);
				if (tmp & 0x8000) tmp |= 0xFFFF0000;
			} else {
				tmp = s9;
			}
			buf = append_u16(buf, tmp);
			sprintf(note, "(%d)", tmp);
			break;
		case 'b':
			buf = append_u16(buf, pc + s11 + 1);
			sprintf(note, "(%d)", pc + s11 + 1);
			break;
		case 'c':
			buf = append_int(buf, s12);
			break;
		case 'e':
			buf = append_u16(buf, (s12 << 4) & 0xffff);
			break;
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
	{ 0b0000000000001111, 0b0000000000000000, "@F @C, @A, @B" },
	{ 0b0000000000001111, 0b0000000000000001, "UND" },
	{ 0b0000000000001111, 0b0000000000000010, "EXT @e" },
	{ 0b0000000000001111, 0b0000000000000011, "MOV @C, +@9" },
	{ 0b0000000000001111, 0b0000000000000100, "LW @C, [@A, @6]" },
	{ 0b0000000000001111, 0b0000000000000101, "SW @C, [@A, @6]" },
	{ 0b0000001000001111, 0b0000000000000110, "B @b" },
	{ 0b0000001000001111, 0b0000001000000110, "BL @b" },
	{ 0b0000000000111111, 0b0000000000000111, "BZ @A, @7" },
	{ 0b0000000000111111, 0b0000000000010111, "BNZ @A, @7" },
	{ 0b1111110001111111, 0b0000000000100111, "B @A" },
	{ 0b1111110001111111, 0b0000000000110111, "BL @A" },
	{ 0b1111111111111111, 0b0000000000001000, "NOP" }, // ADD R0, R0, 0
	{ 0b1111110000001111, 0b0000000000001000, "MOV @C, @A" }, // ADD Rc, Ra, 0
	{ 0b1111110000001111, 0b1111110000001100, "NOT @C, @A" }, // XOR Rc, Ra, -1
	{ 0b0000000000001000, 0b0000000000001000, "@f @C, @A, +@6" },
	{ 0b0000000000000000, 0b0000000000000000, "UND" },
};

static void disassemble0(char *buf, unsigned pc, unsigned instr,
		         unsigned ex, unsigned ev, unsigned verbose) {
	int n = 0;
	for (n = 0 ;; n++) {
		if ((instr & decode[n].mask) == decode[n].value) {
			printinst(buf, pc, instr, decode[n].fmt, ex, ev, verbose);
			return;
		}
	}
	buf[0] = 0;
}

void disassemble(char *buf, unsigned pc, unsigned instr) {
	static unsigned ex = 0;
	static unsigned ev = 0;
	disassemble0(buf, pc, instr, ex, ev, 1);
	if ((instr & 0xF) == 0x2) {
		ex = 1;
		ev = ((instr >> 10) & 0x1F) | ((instr & 0x3F0) << 1) | ((instr >> 4) & 0x800);
	} else {
		ex = 0;
	}
}

#ifdef STANDALONE
int main(int argc, char **argv) {
        char buf[256];
        char line[1024];
        while (fgets(line, 1024, stdin)) {
                unsigned insn = 0xFFFF;
		unsigned ext = 0;
		unsigned pc = 0;
                sscanf(line, "%04x%04x%04x", &insn, &ext, &pc);
                disassemble0(buf, pc, insn, ext >> 12, ext & 0xFFF, 0);
                printf("%s\n", buf);
                fflush(stdout);
        }
        return 0;
}
#endif
