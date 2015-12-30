/* Copyright 2014 Brian Swetland <swetland@frotz.net>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* reusable verilator testbench driver
 * - expects the top module to be testbench(clk);
 * - provides clk to module
 * - handles vcd tracing if compiled with TRACE
 * - allows tracefilename to be specified via -o
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>

#include "Vtestbench.h"
#include "verilated.h"
#include <verilated_vcd_c.h>

static unsigned memory[4096];

void dpi_mem_write(int addr, int data) {
	memory[addr & 0xFFF] = data;
}

void dpi_mem_read(int addr, int *data) {
	*data = (int) memory[addr & 0xFFF];
}

void loadmem(const char *fn) {
	unsigned a = 0;
	FILE *fp = fopen(fn, "r");
	char buf[128];
	if (fp == NULL) {
		fprintf(stderr, "warning: cannot load memory from '%s'\n", fn);
		return;
	}
	while (fgets(buf, 128, fp) != NULL) {
		unsigned n;
		char *x = buf;
		while (isspace(*x)) x++;
		if (*x == '#') continue;
		if ((x[0] == '/') && (x[1] == '/')) continue;
		n = 0;
		if (x[0] == '.') {
			x++;
			while (isdigit(*x)) {
				n <<= 1;
				if (*x == '1') {
					n |= 1;
				}
				x++;
			}
		} else {
			sscanf(x, "%x", &n);
		}
		memory[a++] = n;
		if (a == 4096) break;
	}
	fprintf(stderr, "loaded %d words from '%s'\n", a, fn);
}

#ifdef TRACE
static vluint64_t now = 0;

double sc_time_stamp() {
	return now;
}
#endif

int main(int argc, char **argv) {
	const char *vcdname = "trace.vcd";
	const char *memname = NULL;
	int fd;

	while (argc > 1) {
		if (!strcmp(argv[1], "-trace")) {
#ifdef TRACE
			if (argc < 3) {
				fprintf(stderr,"error: -trace requires argument\n");
				return -1;
			}
			vcdname = argv[2];
			argv += 2;
			argc -= 2;
			continue;
#else
			fprintf(stderr,"error: no trace support\n");
			return -1;
#endif
		} else if (!strcmp(argv[1], "-dump")) {
			if (argc < 3) {
				fprintf(stderr, "error: -dump requires argument\n");
				return -1;
			}
			memname = argv[2];
			argv += 2;
			argc -= 2;
		} else if (!strcmp(argv[1], "-load")) {
			if (argc < 3) {
				fprintf(stderr, "error: -load requires argument\n");
				return -1;
			}
			loadmem(argv[2]);
			argv += 2;
			argc -= 2;
		} else {
			break;
		}
	}

	Verilated::commandArgs(argc, argv);
	Verilated::debug(0);
	Verilated::randReset(2);

	Vtestbench *testbench = new Vtestbench;
	testbench->clk = 0;

#ifdef TRACE
	Verilated::traceEverOn(true);
	VerilatedVcdC* tfp = new VerilatedVcdC;
	testbench->trace(tfp, 99);
	tfp->open(vcdname);
#endif

// first tick, line up with gtk's vert lines
	testbench->eval();
#ifdef TRACE
	tfp->dump(now);
	now += 10;
#endif
	testbench->clk = !testbench->clk;

	while (!Verilated::gotFinish()) {
		testbench->eval();
#ifdef TRACE
		tfp->dump(now);
		now += 5;
#endif
		testbench->clk = !testbench->clk;
	}
#ifdef TRACE
	tfp->close();
#endif
	testbench->final();
	delete testbench;

	if (memname != NULL) {
		fd = open(memname, O_WRONLY | O_CREAT | O_TRUNC, 0640);
		if (fd < 0) {
			fprintf(stderr, "cannot open '%s' for writing\n", memname);
			return -1;
		}
		write(fd, memory, sizeof(memory));
		close(fd);
	}
	return 0;
}

