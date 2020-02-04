// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

struct {
	uint64_t enc;
	const char* name;
	const char* args;
	const char* desc;
} ops[] = {
	{ 0x100000000, "wri",   "w", "wri #    write immediate" },
	{ 0x200000000, "wrp",   "w", "wrp #    write pattern0 #+1 times" },
	{ 0x300000000, "rdc",   "w", "rdi #    read + check vs immediate" },
	{ 0x400000000, "rdp",   "w", "rdp #    read + check vs pattern1 #+1 times" },
	{ 0x500000000, "verify","w", "rdp      check count readbuffer vs pattern1" },
	{ 0x600000000, "rdf",   "w", "rdp      read count into readbuffer" },
	{ 0x700000000, "rdb",   "w", "rdp      read burst count into readbuffer" },
	{ 0xA00000000, "addr",  "w", "addr #   set address" },
	{ 0xF00000000, "wait",  "w", "wait #   wait # cycles" },
	{ 0x080000000, "halt",  "",  "halt     stop processing" },
	{ 0x040000000, "dump",  "w", "dump     display # scope traces" },
	{ 0x020000000, "trigger","", "trigger  trigger scope capture" },
	{ 0x000000001, "p0rst", "",  "p0rst    reset pattern0" },
	{ 0x000000002, "p1rst", "",  "p1rst    reset pattern1" },
	{ 0x000000004, "auto+", "",  "auto+    enable addr auto inc" },
	{ 0x000000008, "auto-", "",  "auto-    disble addr auto inc" },
	{ 0xD00007100, "show",  "b", "show #   show status byte" },
	{ 0x000000000, "", "", "" },
};

unsigned lineno = 1;

const char* token(void) {
	static char buf[64];
	int n = 0;
	for (;;) {
		int c = getchar();
		if (c == '#') { // comment to EOL
			for (;;) {
				c = getchar();
				if (c == EOF) break;
				if (c == '\n') break;
			}
		}
		if (c == '\n') lineno++;
		if (c == EOF) break;
		if (isspace(c)) {
		       if (n) break;
		} else {
			buf[n++] = c;
			if (n == sizeof(buf)) {
				fprintf(stderr, "error: %u: token too large\n", lineno);
				exit(-1);
			}
		}
	}
	buf[n] = 0;
	return buf;
}

uint32_t arg_word(const char* tok) {
	if (tok[0] == 0) {
		fprintf(stderr, "error: %u: missing argument\n", lineno);
		exit(-1);
	}
	if (tok[0] == '.') return strtoul(tok+1, 0, 10);
	else return strtoul(tok, 0, 16);
}
uint32_t arg_byte(const char* tok) {
	uint32_t n = arg_word(tok);
	if (n > 255) {
		fprintf(stderr, "error: %u: byte argument too large\n", lineno);
		exit(-1);
	}
	return n;
}

int main(int argc, char **argv) {
	if (argc != 1) {
		for (unsigned n = 0; ops[n].enc; n++) {
			fprintf(stderr, "%s\n", ops[n].desc);
		}
		return 0;
	}
	for (;;) {
		const char* tok = token();
		if (tok[0] == 0) break;
		for (unsigned n = 0; ops[n].enc; n++) {
			if (!strcasecmp(ops[n].name, tok)) {
				uint64_t op = ops[n].enc;
				const char* args = ops[n].args;
				while (*args) {
					if (*args == 'w') op |= arg_word(token());
					if (*args == 'b') op |= arg_byte(token());
					args++;
				}
				printf("%09lx\n", op);
				goto next;
			}
		}
		fprintf(stderr, "error: %u: unknown opcode '%s'\n", lineno, tok);
		exit(-1);
next: ;
	}
	printf("080000000\n");
	return 0;
}
