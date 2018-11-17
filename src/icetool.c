// Copyright 2015 Brian Swetland <swetland@frotz.net>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

#include "ftdi.h"

#define GPIO_CS_N		0x10
#define GPIO_CDONE		0x40
#define GPIO_CRESET_N		0x80

#define GPIO_DIR		0x93

static unsigned char mpsse_init[] = {
	FTDI_LOOPBACK_OFF,
	FTDI_CLOCK_DIV_5,
	FTDI_DIVISOR_SET, 0x00, 0x00, // 6MHz
	FTDI_GPIO_WRITE_LO, 1 | GPIO_CS_N | GPIO_CRESET_N, GPIO_DIR,
};

// send CS1 8x0 CS0 <data> CS1 8x0 
int spi_tx(FTDI *d, void *data, int len) {
	u8 cmd[13 + 4096 + 7];

	// RST=1 CS=1
	cmd[0] = FTDI_GPIO_WRITE_LO;
	cmd[1] = 1 | GPIO_CRESET_N | GPIO_CS_N;
	cmd[2] = GPIO_DIR;
	// TX 8x 0
	cmd[3] = FTDI_LSB_TX_BYTES_TN,
	cmd[4] = 0;
	cmd[5] = 0;
	cmd[6] = 0;
	// RST=1 CS=0
	cmd[7] = FTDI_GPIO_WRITE_LO;
	cmd[8] = 1 | GPIO_CRESET_N;
	cmd[9] = GPIO_DIR;
	// TX n
	cmd[10] = FTDI_LSB_TX_BYTES_TN,
	cmd[11] = len - 1;
	cmd[12] = (len - 1) >> 8;

	if (len > 4096)
		return -1;
	memcpy(cmd + 13, data, len);
	memcpy(cmd + 13 + len, cmd, 7);
	if (ftdi_send(d, cmd, 13 + len + 7, 1000))
		return -1;
	return 0;
}

void usage(void) {
	fprintf(stderr, 
	"usage:   icetool -load <addr> <hexfile>\n"
	"         icetool -write <addr> <value>...\n"
	);
	exit(1);
}

int main(int argc, char **argv) {
	u16 addr;
	u16 data[2049];
	int n;
	FTDI *d;

	if (argc < 4) {
		usage();
	}
	if (!strcmp(argv[1], "-load")) {
		char buf[1024];
		addr = strtoul(argv[2], 0, 16);
		FILE *fp = fopen(argv[3], "r");
		if (fp == NULL) {
			fprintf(stderr, "cannot open '%s'\n", argv[3]);
			return 1;
		}
		n = 0;
		while (fgets(buf, 1024, fp)) {
			if (!isalnum(buf[0])) continue;
			if (n == 2048) return 1;
			data[1 + n++] = strtoul(buf, 0, 16);
		}
		fclose(fp);
	} else  if (!strcmp(argv[1], "-write")) {
		addr = strtoul(argv[2], 0, 16);
		argc -= 3;
		argv += 3;
		n = 0;
		while (argc > 0) {
			if (argv[0][0] == '/') {
				char *s = argv[0] + 1;
				while (*s != 0) {
					if (n == 2048) return 1;
					data[1 + n++] = *s++;
				}
			} else {
				if (n == 2048) return 1;
				data[1 + n++] = strtoul(argv[0], 0, 16);
			}
			argc--;
			argv++;
		}
	} else {
		usage();
	}
	data[0] = addr;

	if ((d = ftdi_open()) == NULL) {
		return 1;
	}
	if (ftdi_send(d, mpsse_init, sizeof(mpsse_init), 1000) < 0) {
		return 1;
	}

	spi_tx(d, data, (n + 1) * 2);

	return 0;
}
