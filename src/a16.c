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

static unsigned linenumber = 0;
static char linestring[256];
static char *filename;

FILE *ofp = 0;

void die(const char *fmt, ...) {
	va_list ap;
	fprintf(stderr,"%s:%d: ", filename, linenumber);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fprintf(stderr,"\n");
	if (linestring[0])
		fprintf(stderr,"%s:%d: >> %s <<\n", filename, linenumber, linestring);
	exit(1);
}

int is_signed4(unsigned n) {
	if (n & 0x8000) n |= 0xFFFF0000;
	if (n <= 0x7) return 1;
	if ((n & 0xFFFFFFF8) == 0xFFFFFFF8) return 1;
	return 0;
}
int is_signed8(unsigned n) {
	if (n & 0x8000) n |= 0xFFFF0000;
	if (n <= 0xFF) return 1;
	if ((n & 0xFFFFFF80) == 0xFFFFFF80) return 1;
	return 0;
}
int is_signed12(unsigned n) {
	if (n & 0x8000) n |= 0xFFFF0000;
	if (n <= 0x7FF) return 1;
	if ((n & 0xFFFFF800) == 0xFFFFF800) return 1;
	return 0;
}
int is_signed16(unsigned n) {
	if (n < 0xFFFF) return 1;
	if ((n & 0xFFF8000) == 0xFFFF8000) return 1;
	return 0;
}

u16 rom[65535];
u16 PC = 0;

#define TYPE_PCREL_S8	1
#define TYPE_PCREL_S12	2
#define TYPE_ABS_U16	3

struct fixup {
	struct fixup *next;
	unsigned pc;
	unsigned type;
};

struct label {
	struct label *next;
	struct fixup *fixups;
	const char *name;
	unsigned pc;
	unsigned defined;
};

struct label *labels;
struct fixup *fixups;

void fixup_branch(const char *name, int addr, int btarget, int type) {
	unsigned n;

	switch(type) {
	case TYPE_PCREL_S8:
		n = btarget - addr - 1;
		if (!is_signed8(n)) break;
		rom[addr] = (rom[addr] & 0x00FF) | ((n & 0x00FF) << 8);
		return;
	case TYPE_PCREL_S12:
		n = btarget - addr - 1;
		if (!is_signed12(n)) break;
		rom[addr] = (rom[addr] & 0x000F) | ((n & 0x0FFF) << 4);
		return;
	case TYPE_ABS_U16:
		rom[addr] = btarget;
		return;
	default:
		die("unknown branch type %d\n",type);
	}
	die("label '%s' at %08x is out of range of %08x\n", name, btarget, addr);
}

void setlabel(const char *name, unsigned pc) {
	struct label *l;
	struct fixup *f;

	for (l = labels; l; l = l->next) {
		if (!strcasecmp(l->name, name)) {
			if (l->defined) die("cannot redefine '%s'", name);
			l->pc = pc;
			l->defined = 1;
			for (f = l->fixups; f; f = f->next) {
				fixup_branch(name, f->pc, l->pc, f->type);
			}
			return;
		}
	}
	l = malloc(sizeof(*l));
	l->name = strdup(name);
	l->pc = pc;
	l->fixups = 0;
	l->defined = 1;
	l->next = labels;
	labels = l;
}

const char *getlabel(unsigned pc) {
	struct label *l;
	for (l = labels; l; l = l->next)
		if (l->pc == pc)
			return l->name;
	return 0;
}

void uselabel(const char *name, unsigned pc, unsigned type) {
	struct label *l;
	struct fixup *f;

	for (l = labels; l; l = l->next) {
		if (!strcasecmp(l->name, name)) {
			if (l->defined) {
				fixup_branch(name, pc, l->pc, type);
				return;
			} else {
				goto add_fixup;
			}
		}
	}
	l = malloc(sizeof(*l));
	l->name = strdup(name);
	l->pc = 0;
	l->fixups = 0;
	l->defined = 0;
	l->next = labels;
	labels = l;
add_fixup:
	f = malloc(sizeof(*f));
	f->pc = pc;
	f->type = type;
	f->next = l->fixups;
	l->fixups = f;
}

void checklabels(void) {
	struct label *l;
	for (l = labels; l; l = l->next) {
		if (!l->defined) {
			die("undefined label '%s'", l->name);
		}
	}
}
	
void disassemble(char *buf, unsigned pc, unsigned instr);
	
void emit(unsigned instr) {
	rom[PC++] = instr;
}

void save(const char *fn) {
	const char *name;
	unsigned n;
	char dis[128];

	FILE *fp = fopen(fn, "w");
	if (!fp) die("cannot write to '%s'", fn);
	for (n = 0; n < PC; n++) {
		disassemble(dis, n, rom[n]);
		name = getlabel(n);
		if (name) {
			fprintf(fp, "%04x  // %04x: %-25s <- %s\n", rom[n], n, dis, name);
		} else {
			fprintf(fp, "%04x  // %04x: %s\n", rom[n], n, dis);
		}
	}
	fclose(fp);
}

#define MAXTOKEN 32

enum tokens {
	tEOL,
	tCOMMA, tCOLON, tOBRACK, tCBRACK, tDOT, tHASH, tSTRING, tNUMBER,
	tMOV, tAND, tORR, tXOR, tADD, tSUB, tMUL, tMHI,
	tSLT, tSLE, tSHR, tSHL, tBIS, tBIC, tTBS, tBIT,
	tLW, tSW, tNOP, tNOT, tB,  tBL, tBZ, tBNZ,
	tDEBUG,
	tR0, tR1, tR2, tR3, tR4, tR5, tR6, tR7,
	rR8, rR9, rR10, rR11, rR12, tR13, tR14, tR15,
	tSP, tLR,
	tEQU, tWORD, tASCII, tASCIIZ,
	NUMTOKENS,
};

char *tnames[] = {
	"<EOL>",
	",", ":", "[", "]", ".", "#", "<STRING>", "<NUMBER>",
	"MOV", "AND", "ORR", "XOR", "ADD", "SUB", "MUL", "MHI",
	"SLT", "SLE", "SHR", "SHL", "BIS", "BIC", "TBS", "BIT",
	"LW",  "SW",  "NOP", "NOT", "B",   "BL",  "BZ",  "BNZ",
	"DEBUG",
	"R0",  "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7",
	"R8",  "R9",  "R10", "R11", "R12", "R13", "R14", "R15",
	"SP",  "LR",
	"EQU", "WORD", "STRING", "ASCIIZ"
};

#define FIRST_ALU_OP	tMOV
#define LAST_ALU_OP	tBIT
#define FIRST_REGISTER	tR0
#define LAST_REGISTER	tLR

int is_reg(unsigned tok) {
	return ((tok >= FIRST_REGISTER) && (tok <= LAST_REGISTER));
}

int is_alu_op(unsigned tok) {
	return ((tok >= FIRST_ALU_OP) && (tok <= LAST_ALU_OP));
}

unsigned to_func(unsigned tok) {
	return tok - FIRST_ALU_OP;
}

unsigned to_reg(unsigned tok) {
	if (tok == tLR) return 14;
	if (tok == tSP) return 13;
	return tok - FIRST_REGISTER;
}

int is_stopchar(unsigned x) {
	switch (x) {
	case 0:
	case ' ':
	case '\t':
	case '\r':
	case '\n':
	case ',':
	case ':':
	case '[':
	case ']':
	case '.':
	case '"':
	case '#':
		return 1;
	default:
		return 0;
	}
}	
int is_eoschar(unsigned x) {
	switch (x) {
	case 0:
	case '\t':
	case '\r':
	case '"':
		return 1;
	default:
		return 0;
	}
}

int tokenize(char *line, unsigned *tok, unsigned *num, char **str) {
	char *s;
	int count = 0;
	unsigned x, n, neg;
	linenumber++;

	for (;;) {
		x = *line;
	again:
		if (count == 31) die("line too complex");

		switch (x) {
		case 0:
			goto alldone;
		case ' ':
		case '\t':
		case '\r':
		case '\n':			
			line++;
			continue;
		case '/':
			if (line[1] == '/')
				goto alldone;
		case ';':
			goto alldone;	
		case ',':
			str[count] = ",";
			num[count] = 0;
			tok[count++] = tCOMMA;
			line++;
			continue;
		case ':':
			str[count] = ":";
			num[count] = 0;
			tok[count++] = tCOLON;
			line++;
			continue;
		case '[':
			str[count] = "[";
			num[count] = 0;
			tok[count++] = tOBRACK;
			line++;
			continue;
		case ']':
			str[count] = "]";
			num[count] = 0;
			tok[count++] = tCBRACK;
			line++;
			continue;
		case '.':
			str[count] = ".";
			num[count] = 0;
			tok[count++] = tDOT;
			line++;
			continue;
		case '#':
			str[count] = "#";
			num[count] = 0;
			tok[count++] = tHASH;
			line++;
			continue;
		case '"':
			str[count] = ++line;
			num[count] = 0;
			tok[count++] = tSTRING;
			while (!is_eoschar(*line)) line++;
			if (*line != '"')
				die("unterminated string");
			*line++ = 0;
			continue;
		}

		s = line++;
		while (!is_stopchar(*line)) line++;

			/* save the stopchar */
		x = *line;
		*line = 0;

		neg = (s[0] == '-');
		if (neg && isdigit(s[1])) s++;

		str[count] = s;
		if (isdigit(s[0])) {
			num[count] = strtoul(s, 0, 0);
			if(neg) num[count] = -num[count];
			tok[count++] = tNUMBER;
			goto again;
		}
		if (isalpha(s[0])) {
			num[count] = 0;
			for (n = tNUMBER + 1; n < NUMTOKENS; n++) {
				if (!strcasecmp(s, tnames[n])) {
					str[count] = tnames[n];
					tok[count++] = n;
					goto again;
				}
			}

			while (*s) {
				if (!isalnum(*s) && (*s != '_'))
					die("invalid character '%c' in identifier", *s);
				s++;
			}
			tok[count++] = tSTRING;
			goto again;
		}
		die("invalid character '%c'", s[0]);
	}

alldone:			
	str[count] = "";
	num[count] = 0;
	tok[count++] = tEOL;
	return count;
}

void expect(unsigned expected, unsigned got) {
	if (expected != got)
		die("expected %s, got %s", tnames[expected], tnames[got]);
}

void expect_register(unsigned got) {
	if (!is_reg(got))
		die("expected register, got %s", tnames[got]);
}

#define REG(n) (tnames[FIRST_REGISTER + (n)])

// various fields
#define _OP(n)		(((n) & 15) << 0)
#define _A(n)		(((n) & 15) << 4)
#define _B(n)		(((n) & 15) << 8)
#define _FHI(n)		(((n) & 15) << 12)
#define _FLO(n)		(((n) & 15) << 8)
#define _I4(n)		(((n) & 15) << 12)
#define _I8(n)		(((n) & 0xFF) << 8)
#define _I12(n)		(((n) & 0xFFF) << 4)

#define OP_MOV_RA_S8		0x0000
#define OP_MHI_RA_S8		0x0001
#define OP_ALU_RA_RA_RB		0x0002
#define OP_ALU_RA_RA_S4		0x0003
#define OP_ALU_R0_RA_RB		0x0004
#define OP_ALU_R1_RA_RB		0x0005
#define OP_ALU_R2_RA_RB		0x0006
#define OP_ALU_R3_RA_RB		0x0007
#define OP_LW_RB_S4		0x0008
#define OP_SW_RB_S4		0x0009
#define OP_BNZ_RA_S8		0x000A
#define OP_BZ_RA_S8		0x000B
#define OP_B_S12		0x000C
#define OP_BL_S12		0x000D
#define OP_B_RB			0x000E
#define OP_BL_RB		0x100E
#define OP_NOP			0x200E

#define ALU_MOV 0
#define ALU_AND 1
#define ALU_ORR 2
#define ALU_XOR 3
#define ALU_ADD 4
#define ALU_SUB 5
#define ALU_SHR 6
#define ALU_SHL 7

#define T0 tok[0]
#define T1 tok[1]
#define T2 tok[2]
#define T3 tok[3]
#define T4 tok[4]
#define T5 tok[5]
#define T6 tok[6]
#define T7 tok[7]

void assemble_line(int n, unsigned *tok, unsigned *num, char **str) {
	unsigned instr = 0;
	unsigned tmp;
	if (T0 == tSTRING) {
		if (T1 == tCOLON) {
			setlabel(str[0], PC);
			tok += 2;
			num += 2;
			str += 2;
			n -= 2;
		} else {
			die("unexpected identifier '%s'", str[0]);
		}
	}

	switch(T0) {
	case tEOL:
		/* blank lines are fine */
		return;
	case tNOP:
		emit(OP_NOP);
		return;
	case tNOT:
		/* XOR rX, rX, -1 */
		expect_register(T1);
		emit(OP_ALU_RA_RA_S4 | _A(to_reg(T1)) | _I4(-1) | ALU_XOR);
		return;
	case tMOV:
		expect_register(T1);
		expect(tCOMMA, T2);
		if (is_reg(T3)) {
			emit(OP_ALU_RA_RA_RB | _A(to_reg(T1)) | _B(to_reg(T3)) | ALU_MOV);
			return;
		}
		expect(tNUMBER, T3);
		if (is_signed8(num[3])) {
			emit(OP_MOV_RA_S8 | _A(to_reg(T1)) | _I8(num[3]));
			return;
		} else {
			emit(OP_MOV_RA_S8 | _A(to_reg(T1)) | _I8(num[3]));
			emit(OP_MHI_RA_S8 | _A(to_reg(T1)) | _I8((num[3] >> 8)));
		}
		return;
	case tMHI:
		expect_register(T1);
		expect(tCOMMA, T2);
		expect(tNUMBER, T3);
		// range
		emit(OP_MHI_RA_S8 | _A(to_reg(T1)) | _I8(num[3]));
		return;
	case tLW:
	case tSW:
		instr = (T0 == tLW ? OP_LW_RB_S4 : OP_SW_RB_S4);
		expect_register(T1);
		expect(tCOMMA, T2);
		expect(tOBRACK, T3);
		expect_register(T4);
		if (T5 == tCOMMA) {
			expect(tNUMBER, T6);
			expect(tCBRACK, T7);
			tmp = num[6];
		} else {
			expect(tCBRACK, T5);
			tmp = 0;
		}
		if (!is_signed4(tmp)) die("index too large");
		emit(instr | _A(to_reg(T1)) | _B(to_reg(T4)) | _I4(tmp));
		return;
	case tB:
	case tBL:
		if (is_reg(T1)) {
			instr = (T0 == tB) ? OP_B_RB : OP_BL_RB;
			emit(instr | _B(to_reg(T1)));
		} else {
			instr = (T0 == tB) ? OP_B_S12 : OP_BL_S12;
			if (T1 == tSTRING) {
				emit(instr);
				uselabel(str[1], PC - 1, TYPE_PCREL_S12);
			} else if (T1 == tDOT) {
				emit(instr | _I12(-1));
			} else {
				die("expected register or address");
			}
		}
		return;
	case tBZ:
	case tBNZ:
		instr = (T0 == tBZ) ? OP_BZ_RA_S8 : OP_BNZ_RA_S8;
		expect_register(T1);
		expect(tCOMMA, T2);
		if (T3 == tSTRING) {
			emit(instr | _A(to_reg(T1)));
			uselabel(str[3], PC - 1, TYPE_PCREL_S8);
		} else if (T3 == tDOT) {
			emit(instr | _A(to_reg(T1)) | _I12(-1));
		} else {
			die("expected register or address");
		}
		return;
	case tDEBUG:
		expect_register(T1);
		expect(tCOMMA, T2);
		expect(tNUMBER, T3);
		emit(OP_NOP | _FLO(num[3]) | _A(to_reg(T1)));
		return;
	case tWORD:
		tmp = 1;
		for (;;) {
			if (tok[tmp] == tSTRING) {
				emit(0);
				uselabel(str[tmp++], PC - 1, TYPE_ABS_U16);
			} else {
				expect(tNUMBER, tok[tmp]);
				emit(num[tmp++]);
			}
			if (tok[tmp] != tCOMMA)
				break;
			tmp++;
		}
		return;
	case tASCII:
	case tASCIIZ: {
		unsigned n = 0, c = 0; 
		const unsigned char *s = (void*) str[1];
		expect(tSTRING, tok[1]);
		while (*s) {
			n |= ((*s) << (c++ * 8));
			if (c == 2) {
				emit(n);
				n = 0;
				c = 0;
			}
			s++;
		}
		emit(n);
		return;
	}
	}
	if (is_alu_op(T0)) {
		expect_register(T1);
		expect(T2, tCOMMA);
		expect_register(T3);
		expect(T4, tCOMMA);
		if (T5 == tNUMBER) {
			if (T1 != T3) {
				die("both registers must be the same in this form");
			}
			if (is_signed4(num[5])) {
				emit(OP_ALU_RA_RA_S4 | _A(to_reg(T1)) | _FLO(to_func(T0)) | _I4(num[5]));
				return;
			} else {
				// auto use R15 as scratch?
				die("immediate out of range (s4)");
			}
		} else if (is_reg(T5)) {
			if (T1 == T3) {
				emit(OP_ALU_RA_RA_RB | _A(to_reg(T1)) | _B(to_reg(T5)) | _FHI(to_func(T0)));
				return;
			} 
			switch (T1) {
			case tR0: instr = OP_ALU_R0_RA_RB; break;
			case tR1: instr = OP_ALU_R1_RA_RB; break;
			case tR2: instr = OP_ALU_R2_RA_RB; break;
			case tR3: instr = OP_ALU_R3_RA_RB; break;
			default:
				die("three-reg ALU ops require R0-R3 for the first register");
			}
			emit(instr | _A(to_reg(T3)) | _B(to_reg(T5)) | _FHI(to_func(T0)));
		} else {
			die("expected register or #, got %s", tnames[tok[5]]);
		}
		return;
	}

	die("HUH");
}

void assemble(const char *fn) {
	FILE *fp;
	char line[256];
	int n;

	unsigned tok[MAXTOKEN];
	unsigned num[MAXTOKEN];
	char *str[MAXTOKEN];
	char *s;

	fp = fopen(fn, "r");
	if (!fp) die("cannot open '%s'", fn);

	while (fgets(line, sizeof(line)-1, fp)) {
		strcpy(linestring, line);
		s = linestring;
		while (*s) {
			if ((*s == '\r') || (*s == '\n')) *s = 0;
			else s++;
		}
		n = tokenize(line, tok, num, str);
#if DEBUG
		{
			int i
			printf("%04d: (%02d)  ", linenumber, n);
			for (i = 0; i < n; i++)
				printf("%s ", tnames[tok[i]]);
			printf("\n");
		}
#endif
		assemble_line(n, tok, num, str);
	}
}

int main(int argc, char **argv) {
	const char *outname = "out.hex";
	filename = argv[1];

	if (argc < 2)
		die("no file specified");
	if (argc == 3)
		outname = argv[2];

	assemble(filename);
	linestring[0] = 0;
	checklabels();
	save(outname);

	return 0;
}
