// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

#pragma once

#include <stdint.h>

static uint8_t crc8tab[256] = {
    "\x00\x72\xe4\x96\xf1\x83\x15\x67\xdb\xa9\x3f\x4d\x2a\x58\xce\xbc"
    "\x8f\xfd\x6b\x19\x7e\x0c\x9a\xe8\x54\x26\xb0\xc2\xa5\xd7\x41\x33"
    "\x27\x55\xc3\xb1\xd6\xa4\x32\x40\xfc\x8e\x18\x6a\x0d\x7f\xe9\x9b"
    "\xa8\xda\x4c\x3e\x59\x2b\xbd\xcf\x73\x01\x97\xe5\x82\xf0\x66\x14"
    "\x4e\x3c\xaa\xd8\xbf\xcd\x5b\x29\x95\xe7\x71\x03\x64\x16\x80\xf2"
    "\xc1\xb3\x25\x57\x30\x42\xd4\xa6\x1a\x68\xfe\x8c\xeb\x99\x0f\x7d"
    "\x69\x1b\x8d\xff\x98\xea\x7c\x0e\xb2\xc0\x56\x24\x43\x31\xa7\xd5"
    "\xe6\x94\x02\x70\x17\x65\xf3\x81\x3d\x4f\xd9\xab\xcc\xbe\x28\x5a"
    "\x9c\xee\x78\x0a\x6d\x1f\x89\xfb\x47\x35\xa3\xd1\xb6\xc4\x52\x20"
    "\x13\x61\xf7\x85\xe2\x90\x06\x74\xc8\xba\x2c\x5e\x39\x4b\xdd\xaf"
    "\xbb\xc9\x5f\x2d\x4a\x38\xae\xdc\x60\x12\x84\xf6\x91\xe3\x75\x07"
    "\x34\x46\xd0\xa2\xc5\xb7\x21\x53\xef\x9d\x0b\x79\x1e\x6c\xfa\x88"
    "\xd2\xa0\x36\x44\x23\x51\xc7\xb5\x09\x7b\xed\x9f\xf8\x8a\x1c\x6e"
    "\x5d\x2f\xb9\xcb\xac\xde\x48\x3a\x86\xf4\x62\x10\x77\x05\x93\xe1"
    "\xf5\x87\x11\x63\x04\x76\xe0\x92\x2e\x5c\xca\xb8\xdf\xad\x3b\x49"
    "\x7a\x08\x9e\xec\x8b\xf9\x6f\x1d\xa1\xd3\x45\x37\x50\x22\xb4\xc6"
};

unsigned crc8(unsigned crc, void* ptr, size_t len) {
	uint8_t* p = ptr;
	while (len-- > 0) {
		crc = crc8tab[crc ^ (*p++)];
	}
	return crc;
}

#ifdef CRC8_MAKE_TABLE
// 0x9C 10011100x // koopman notation (low bit implied)
// 0x39 x00111001 // truncated notation (high bit implied)
//
// LSB
#define POLY 0x39

void make_crc8tab(void) {
	unsigned c, d, i;
	for (d = 0; d < 256; d++) {
		c = d;
		for (i = 0; i < 8; i++) {
			if (c & 0x80) {
				c = (POLY) ^ (c << 1);
			} else {
				c <<= 1;
			}
		}
		//crc8tab[d] = c; //MSB
		crc8tab[rev(d)] = rev(c); //LSB
	}

	printf("static uint8_t crc8tab[256] = {");
	for (i = 0; i < 256; i++) {
		if ((i % 16) == 0) {
			printf(i ? "\"\n    \"" : "\n    \"");
		}
		printf("\\x%02x", crc8tab[i]);
	}
	printf("\"\n};\n");
}
#endif

#ifdef CRC8_BIT_SERIAL_IMPL
#define POLY 0x39

static unsigned rev(unsigned n) {
	unsigned m = 0;
	for (unsigned i = 0; i < 8; i++) {
		m = (m << 1) | (n & 1);
		n >>= 1;
	}
	return m;
}

unsigned crc8_serial(unsigned crc, unsigned data) {
	for (unsigned n = 0; n < 8; n++) {
		unsigned din = data & 1;
		data >>= 1;
		unsigned crchi = (crc & 0x80) ? 1 : 0;
		din ^= crchi;
		crc <<= 1;
		if (din) crc ^= POLY;
	}
	return crc & 0xFF;
}

unsigned crc8(void* ptr, size_t len) {
	uint8_t* p = ptr;
	unsigned crc = 0xff;
	while (len-- > 0) {
		crc = crc8_serial(crc, *p++);
	}
	return rev(crc);
}
#endif
