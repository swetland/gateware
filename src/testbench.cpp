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

static unsigned memory[65536];

void dpi_mem_write(int addr, int data) {
	//fprintf(stdout,"WR %08x = %08x\n", addr, data);
	memory[addr & 0xFFFF] = data;
}

void dpi_mem_read(int addr, int *data) {
	//fprintf(stdout,"RD %08x = %08x\n", addr, memory[addr & 0xFFFF]);
	*data = (int) memory[addr & 0xFFFF];
}

int dpi_mem_read2(int addr) {
	//fprintf(stdout,"Rd %08x = %08x\n", addr, memory[addr & 0xFFFF]);
	return (int) memory[addr & 0xFFFF];
}

void loadmem(const char *fn) {
	unsigned a = 0;
	FILE *fp = fopen(fn, "r");
	char buf[128];
	memset(memory, 0xaa, sizeof(memory));
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
		//fprintf(stderr,"mem[%08x] = %08x\n",a,n);
		memory[a++] = n;
		if (a == 4096) break;
	}
}

#ifdef VGA
#define FRAME_W 800
#define FRAME_H 524
#define FRAME_TICKS (FRAME_W * FRAME_H)
#define FRAME_BYTES (FRAME_W * FRAME_H * 3)

static unsigned vga_ticks = 0;
static unsigned vga_frames = 0;
static unsigned char vga_data[2][FRAME_BYTES];
static unsigned vga_active;

static int vga_tick(int hs, int vs, int fr, int red, int grn, int blu) {
	if (fr) {
		//fprintf(stderr, "VGA: frame=%u active=%u ticks=%u\n",
		//	vga_frames, vga_active, vga_ticks);
		if (vga_ticks < FRAME_TICKS) {
			fprintf(stderr, "VGA: frame too small: %u ticks\n", vga_ticks);
		} else if (vga_ticks > FRAME_TICKS) {
			fprintf(stderr, "VGA: frame too large: %u ticks\n", vga_ticks);
		} else if (memcmp(vga_data[vga_active], vga_data[!vga_active], FRAME_BYTES)) {
			char tmp[256];
			sprintf(tmp, "frame%04d.ppm", vga_frames);
			int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
			if (fd < 0) {
				fprintf(stderr, "VGA: cannot write '%s'\n", tmp);
			} else {
				sprintf(tmp, "P6\n%u %u 15\n", FRAME_W, FRAME_H);
				write(fd, tmp, strlen(tmp));
				write(fd, vga_data[vga_active], FRAME_BYTES);
				close(fd);
			}
			vga_active = !vga_active;
		} else {
			//fprintf(stderr, "VGA: frame %u did not change\n", vga_frames);
		}
		memset(vga_data[vga_active], 0xff, FRAME_BYTES);
		vga_ticks = 0;
		vga_frames++;
		if (vga_frames == 5) {
			return -1;
		}
	}
	if (vga_ticks < FRAME_TICKS) {
		unsigned char* pixel = vga_data[vga_active] + vga_ticks * 3;
		if (hs == 0) {
			pixel[0] = 0xf;
			pixel[1] = 0x8;
			pixel[2] = 0x0;
		} else if (vs == 0) {
			pixel[0] = 0xf;
			pixel[1] = 0x0;
			pixel[2] = 0xf;
		} else {
			pixel[0] = red;
			pixel[1] = grn;
			pixel[2] = blu;
		}
	}
	vga_ticks++;
	return 0;
}
#endif

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

	while (!Verilated::gotFinish()) {
		testbench->clk = 1;
		testbench->eval();
#ifdef TRACE
		tfp->dump(now);
		now += 5;
#endif
#ifdef VGA
		if (vga_tick(testbench->vga_hsync, testbench->vga_vsync,
			     testbench->vga_frame, testbench->vga_red,
			     testbench->vga_grn, testbench->vga_blu)) {
			break;
		}
#endif
		testbench->clk = 0;
		testbench->eval();
#ifdef TRACE
		tfp->dump(now);
		now += 5;
#endif
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

