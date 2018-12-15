// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include <sys/fcntl.h>

#include "crc8.h"

int openserial(const char *device, unsigned speed) {
	struct termios tio;
	int fd;

	/* open the serial port non-blocking to avoid waiting for cd */
	if ((fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY)) < 0) {
		return -1;
	}

        memset(&tio, 0, sizeof(tio));
        tio.c_iflag |= IGNBRK | IGNPAR; // ignore break, ignore parity/frame err
        tio.c_cflag |= CS8 | CREAD | CLOCAL; // 8bit, enable rx, no modem lines
        tio.c_cc[VMIN] = 1; // min chars to read
        tio.c_cc[VTIME] = 0; // blocking read
        cfmakeraw(&tio);
        cfsetispeed(&tio, speed);
        cfsetospeed(&tio, speed);

	if (tcsetattr(fd, TCSAFLUSH, &tio)) {
		fprintf(stderr, "error: cannot set serial port attributes: %d %s\n", errno, strerror(errno));
		close(fd);
		return -1;
	}

	return fd;
}

void cmd(int fd, unsigned cmd, unsigned data) {
	uint8_t msg[7];
	msg[0] = 0xCD;
	msg[1] = cmd;
	msg[2] = data;
	msg[3] = data >> 8;
	msg[4] = data >> 16;
	msg[5] = data >> 24;
	msg[6] = crc8(0xFF, msg, 6);
	write(fd, msg, 7);
}

void cmd_wr_u8(int fd, uint32_t addr, uint8_t* p, size_t len) {
	if (len > 4096) {
		return;
	}
	uint8_t data[4097*7];
	uint8_t* msg = data;

	msg[0] = 0xCD;
	msg[1] = 0x01;
	msg[2] = addr;
	msg[3] = addr >> 8;
	msg[4] = addr >> 16;
	msg[5] = addr >> 24;
	msg[6] = crc8(0xFF, msg, 6);
	msg += 7;

	while (len-- > 0) {
		msg[0] = 0xCD;
		msg[1] = 0x00;
		msg[2] = *p++;
		msg[3] = 0x00;
		msg[4] = 0x00;
		msg[5] = 0x00;
		msg[6] = crc8(0xFF, msg, 6);
		msg += 7;
	}
	write(fd, data, msg - data);
}

void cmd_wr_u16(int fd, uint32_t addr, uint16_t* p, size_t len) {
	if (len > 4096) {
		return;
	}
	uint8_t data[4097*7];
	uint8_t* msg = data;

	msg[0] = 0xCD;
	msg[1] = 0x01;
	msg[2] = addr;
	msg[3] = addr >> 8;
	msg[4] = addr >> 16;
	msg[5] = addr >> 24;
	msg[6] = crc8(0xFF, msg, 6);
	msg += 7;

	while (len-- > 0) {
		msg[0] = 0xCD;
		msg[1] = 0x00;
		msg[2] = *p;
		msg[3] = *p >> 8;
		msg[4] = 0x00;
		msg[5] = 0x00;
		msg[6] = crc8(0xFF, msg, 6);
		msg += 7;
		p++;
	}
	write(fd, data, msg - data);
}

int usage(void) {
	fprintf(stderr,
		"usage:   udebug <port> <command>*\n"
		"\n"
		"command: -load <addr> <hexfile>     - write hex file\n"
		"         -write <addr> <value>...   - write wolds\n"
		"         -reset                     - processor RST=1\n"
		"         -run                       - processor RST=0\n"
		"         -error                     - cause link error\n"
		"         -clear                     - clear link error\n"
	       );
	return -1;
}

int main(int argc, char **argv) {
	uint16_t addr;
	uint16_t data[4096];
	size_t n;

	if (argc < 2) {
		return usage();
	}

	int sfd = openserial(argv[1], B1000000);
	if (sfd < 0) {
		fprintf(stderr, "error: cannot open serial port '%s'\n", argv[1]);
		return -1;
	}

	argc -= 2;
	argv += 2;
	while (argc > 0) {
		if (!strcmp(argv[0], "-load")) {
			if (argc < 3) {
				return usage();
			}
			char buf[1024];
			addr = strtoul(argv[1], 0, 16);
			FILE *fp = fopen(argv[2], "r");
			if (fp == NULL) {
				fprintf(stderr, "error: cannot open '%s'\n", argv[3]);
				return -1;
			}
			n = 0;
			while (fgets(buf, 1024, fp)) {
				if (!isalnum(buf[0])) continue;
				if (n == 4096) return -1;
				data[n++] = strtoul(buf, 0, 16);
			}
			fclose(fp);
			cmd_wr_u16(sfd, addr, data, n);
			argc -= 3;
			argv += 3;
		} else if (!strcmp(argv[0], "-write")) {
			if (argc < 3) {
				return usage();
			}
			addr = strtoul(argv[1], 0, 16);
			argc -= 2;
			argv += 2;
			n = 0;
			while (argc > 0) {
				if (argv[0][0] == '-') {
					break;
				}
				if (argv[0][0] == '/') {
					char *s = argv[0] + 1;
					while (*s != 0) {
						if (n == 4096) return -1;
						data[n++] = *s++;
					}
				} else {
					if (n == 4096) return -1;
					data[n++] = strtoul(argv[0], 0, 16);
				}
				argc--;
				argv++;
			}
			cmd_wr_u16(sfd, addr, data, n);
		} else if (!strcmp(argv[0], "-reset")) {
			data[0] = 1;
			cmd_wr_u16(sfd, 0xF000, data, 1);
			argc--;
			argv++;
		} else if (!strcmp(argv[0], "-run")) {
			data[0] = 0;
			cmd_wr_u16(sfd, 0xF000, data, 1);
			argc--;
			argv++;
		} else if (!strcmp(argv[0], "-error")) {
			cmd(sfd, 0xFF, 0);
			argc--;
			argv++;
		} else if (!strcmp(argv[0], "-clear")) {
			cmd(sfd, 0x02, 0);
			argc--;
			argv++;
		} else {
			usage();
		}
	}

	close(sfd);
	return 0;
}
