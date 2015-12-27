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

const char *condcode[] = {
	"EQ", "NE", "CS", "CC", "MI", "PL", "VS", "VC",
	"HI", "LS", "GE", "LT", "GT", "LE", "", "NV",
};

const char *regname[] = {
	"R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7",
	"R8", "R9", "R10", "R11", "R12", "R13", "R14", "R15"
};

const char *alufunc[] = {
	"MOV", "AND", "ORR", "XOR", "ADD", "SUB", "SHR", "SHL",
};

int printinst(char *buf, unsigned pc, unsigned instr, unsigned next, const char *fmt) {
	int words = 1;
	unsigned a = (instr >> 8) & 15;
	unsigned b = (instr >> 4) & 15;
	unsigned f = (instr >> 0) & 15;
	int s4alu = (b & 0x8) ? (b | 0xFFFFFFF0) : (b & 0xF);
	int s4mem = (instr & 0x8) ? (instr | 0xFFFFFFF0) : (instr & 0xF);
	int s8 = (instr & 0x80) ? (instr | 0xFFFFFF00) : (instr & 0xFF);
	int s12 = (instr & 0x800) ? (instr | 0xFFFF800) : (instr & 0xFFF);

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
			buf = append(buf, condcode[a]);
			break;
		case 'F':
			buf = append(buf, alufunc[f]);
			break;
		case 'f': // alt alu func
			buf = append(buf, alufunc[b]);
			break;
		case 'i':
			buf = append_int(buf, s4alu);
			break;
		case '4':
			buf = append_int(buf, s4mem);
			break;
		case '8':
			buf = append_int(buf, s8);
			break;
		case 's':
			buf = append_int(buf, s12);
			break;
		case 'U':
			words = 2;
			buf = append(buf, "0x");
			buf = append_u16(buf, next);
			break;
		case 0:
			goto done;
		}
		fmt++;
	}
done:
	*buf = 0;
	return words;
}

struct {
	u16 mask;
	u16 value;
	const char *fmt;
} decode[] = {
	{ 0b1111111111111111, 0b0000000000000000, "NOP" },
	{ 0b1111000000001111, 0b0000000000000000, "MOV @A, @B" },
	{ 0b1111000000000000, 0b0000000000000000, "@F @A, @A, @B" },
	{ 0b1111000000000000, 0b0001000000000000, "MOV @A, #@8" },
	{ 0b1111000000001111, 0b0010000000000000, "MOV @A, #@i" },
	{ 0b1111000000000000, 0b0010000000000000, "@F @A, @A, #@i" },
	{ 0b1111000000001111, 0b0011000000000000, "MOV @B, #@U" },
	{ 0b1111000000000000, 0b0011000000000000, "@F @B, @A, #@U" },
	{ 0b1111000000001111, 0b0100000000000000, "MOV R0, @B" },
	{ 0b1111000000000000, 0b0100000000000000, "@F R0, @A, @B" },
	{ 0b1111000000001111, 0b0101000000000000, "MOV R1, @B" },
	{ 0b1111000000000000, 0b0101000000000000, "@F R1, @A, @B" },
	{ 0b1111000000001111, 0b0110000000000000, "MOV R2, @B" },
	{ 0b1111000000000000, 0b0110000000000000, "@F R2, @A, @B" },
	{ 0b1111000000001111, 0b0111000000000000, "MOV R3, @B" },
	{ 0b1111000000000000, 0b0111000000000000, "@F R3, @A, @B" },
	{ 0b1111000000001111, 0b1000000000000000, "LW @A, [@B]" },
	{ 0b1111000000000000, 0b1000000000000000, "LW @A, [@B, @4]" },
	{ 0b1111000000001111, 0b1001000000000000, "SW @A, [@B]" },
	{ 0b1111000000000000, 0b1001000000000000, "SW @A, [@B, @4]" },
	{ 0b1111000000000000, 0b1010000000000000, "B@C @8" },
	{ 0b1111000000001000, 0b1011000000000000, "B@C @B" },
	{ 0b1111000000001000, 0b1011000000001000, "BL@C @B" },
	{ 0b1111000000000000, 0b1100000000000000, "B @s" },
	{ 0b1111000000000000, 0b1101000000000000, "BL @s" },
	{ 0b0000000000000000, 0b0000000000000000, "UNDEFINED" },
};

int disassemble(char *buf, unsigned pc, unsigned instr, unsigned next) {
	int n = 0;
	for (n = 0 ;; n++) {
		if ((instr & decode[n].mask) == decode[n].value) {
			return printinst(buf, pc, instr, next, decode[n].fmt);
		}
	}
	return 1;
}

