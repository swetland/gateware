// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

#ifdef SDRAM

#include <stdint.h>
#include <string.h>
#include <stdio.h>

#include "sim-sdram.h"

// Geometry and Timing Configuration
//
#if 1
#define BANKBITS 1
#define COLBITS  8
#define ROWBITS  11
#else
#define BANKBITS 2
#define COLBITS  9
#define ROWBITS  13
#endif

#define tRCD 3
#define tRC  8
#define tRRD 3
#define tRP  3
#define tWR  2
#define tMRD 3

// Derived Parameters
//
#define ALLBITS   (ROWBITS + BANKBITS + COLBITS)
#define ALLWORDS  (1 << ALLBITS)

#define BANKS     (1 << BANKBITS)
#define ROWS      (1 << ROWBITS)
#define COLS      (1 << COLBITS)

#define BANKMASK  (BANKS - 1)
#define ROWMASK   (ROWS - 1)
#define COLMASK   (COLS - 1)

#define ADDR(bank, row, col) (\
	(((bank) & BANKMASK) << (ROWBITS + COLBITS)) |\
	(((row) & ROWMASK) << (COLBITS)) |\
	((col) & COLMASK))

#define CMD_SET_MODE  0b000
#define CMD_REFRESH   0b001
#define CMD_PRECHARGE 0b010
#define CMD_ACTIVE    0b011
#define CMD_WRITE     0b100
#define CMD_READ      0b101
#define CMD_STOP      0b110
#define CMD_NOP       0b111

#define BANK_UNKNOWN    0
#define BANK_IDLE       1
#define BANK_ACTIVE     2
#define BANK_READ       3
#define BANK_WRITE      4
#define BANK_PRECHARGE  5
#define BANK_REFRESH    6
#define BANK_OPENING    7

static const char* cname(unsigned n) {
	switch (n) {
	case CMD_SET_MODE:   return "MODE";
	case CMD_REFRESH:    return "REFR";
	case CMD_PRECHARGE:  return "PCHG";
	case CMD_ACTIVE:     return "ACTV";
	case CMD_WRITE:      return "WRIT";
	case CMD_READ:       return "READ";
	case CMD_STOP:       return "STOP";
	case CMD_NOP:        return "NOP";
	default: return "INVL";
	}
}

static const char* sname(unsigned n) {
	switch (n) {
	case BANK_UNKNOWN:    return "UNKN";
	case BANK_IDLE:       return "IDLE";
	case BANK_ACTIVE:     return "ACTV";
	case BANK_READ:       return "READ";
	case BANK_WRITE:      return "WRIT";
	case BANK_PRECHARGE:  return "PCHG";
	case BANK_REFRESH:    return "REFR";
	case BANK_OPENING:    return "OPEN";
	default: return "INVL";
	}
}

#define SN(n) sname(bank[n].state)


struct {
	unsigned state;
	unsigned rowaddr;
	unsigned busy; // cycles until activated, precharged
} bank[BANKS];

static struct {
	unsigned pipe_data_o[tRCD]; // data out pipe
	unsigned pipe_data_e[tRCD]; // data exists pipe
	unsigned rd_burst;
	unsigned wr_burst;

	// activity
	unsigned state; // BANK_READ or _WRITE
	unsigned bankno; // bank number 
	unsigned count; // remaining cycles of that state
	unsigned addr;
	unsigned ap; // auto-precharge
} sdram;

//  RD Bn Rnnnnn Cnnn -- Bn XXXXXXXX NNNN  Bn XXXXXXXX NNNN 
//  
static uint16_t memory[ALLWORDS];

void sim_dump(void) {
	for (unsigned n = 0; n < BANKS; n++) {
		printf("B%u %-4s %04x  ", n, SN(n), bank[n].busy);
	}
	if (sdram.state != BANK_IDLE) {
		printf("%s B%u R%05x C%03x (%u)\n",
			sdram.state == BANK_WRITE ? "WR" : "RD",
			sdram.bankno, bank[sdram.bankno].rowaddr,
			sdram.addr & COLMASK, sdram.count);
	} else {
		printf("\n");
	}
}

void sim_sdram_init(void) {
	memset(bank, 0, sizeof(bank));
	memset(&sdram, 0, sizeof(sdram));
	memset(memory, 0xFE, ALLWORDS * 2);
	sdram.rd_burst = 1;
	sdram.wr_burst = 1;
	sdram.state = BANK_IDLE;
}

int sim_sdram(unsigned ctl, unsigned addr, unsigned din, unsigned* dout) {
	unsigned a_bank = (addr >> ROWBITS) & BANKMASK;
	unsigned a_row = addr & ROWMASK;
	unsigned a_col = addr & COLMASK;
	unsigned a_a10 = (addr >> 10) & 1;

	printf("(%-4s) %06x %04x  ", cname(ctl), addr, din);
	for (unsigned n = 0; n < 3; n++) {
		if (sdram.pipe_data_e[n]) {
			printf("<%04x", sdram.pipe_data_o[n]);
		} else {
			printf("<----");
		}
	}
	printf("<  ");
	sim_dump();

	// drain output data pipe
	if (sdram.pipe_data_e[0]) {
		*dout = sdram.pipe_data_o[0];
	} else {
		*dout = 0xE7E7; // DEBUG AID
	}
	sdram.pipe_data_e[0] = sdram.pipe_data_e[1];
	sdram.pipe_data_o[0] = sdram.pipe_data_o[1];
	sdram.pipe_data_e[1] = sdram.pipe_data_e[2];
	sdram.pipe_data_o[1] = sdram.pipe_data_o[2];
	sdram.pipe_data_e[2] = 0;
	sdram.pipe_data_o[2] = 0;

	// process bank timers
	for (unsigned n = 0; n < BANKS; n++) {
		if (bank[n].busy == 0) continue;
		bank[n].busy--;
		if (bank[n].busy != 0) continue;
		switch (bank[n].state) {
		case BANK_PRECHARGE:
			bank[n].state = BANK_IDLE;
			break;
		case BANK_REFRESH:
			bank[n].state = BANK_IDLE;
			break;
		case BANK_OPENING:
			bank[n].state = BANK_ACTIVE;
			break;
		default:
			printf("sdram: bank%d bad timer state %s\n", n, SN(n));
			return -1;
		}
	}
	
	switch (ctl) {
	case CMD_SET_MODE:
	case CMD_REFRESH:
		for (unsigned n = 0; n < BANKS; n++) {
			if (bank[n].state != BANK_IDLE) {
				printf("sdram: bank%d not idle for %s\n", n,
					(ctl == CMD_SET_MODE) ? "SET_MODE" : "REFRESH");
				return -1;
			}
		}
		// TODO
		break;
	case CMD_PRECHARGE:
		for (unsigned n = 0; n < BANKS; n++) {
			if (a_a10 || (a_bank == n)) {
				if (bank[n].state == BANK_IDLE) {
					continue; // NOP
				}
				if ((bank[n].state == BANK_READ) ||
				    (bank[n].state == BANK_WRITE)) { 
					bank[n].state = BANK_ACTIVE;
					sdram.state = BANK_IDLE;
					continue; // cancel ongoing R/W
				}
				if ((bank[n].state == BANK_ACTIVE) ||
					(bank[n].state == BANK_UNKNOWN)) {
					bank[n].state = BANK_PRECHARGE;
					bank[n].busy = tRP - 1;
					continue;
				}
				printf("sdram: bank%d cannot PRECHARGE from %s\n", n, SN(n));
				return -1;
			}
		}
		break;
	case CMD_ACTIVE:
		if (bank[a_bank].state != BANK_IDLE) {
			printf("sdram: bank%d cannot go ACTIVE from %s\n", a_bank, SN(a_bank));
			return -1;
		}
		bank[a_bank].state = BANK_OPENING;
		bank[a_bank].busy = tRP - 1;
		break;
	case CMD_READ:
	case CMD_WRITE:
		if (bank[a_bank].state == BANK_WRITE) {
			// truncate write, start new write burst
		} else if (bank[a_bank].state == BANK_READ) {
			// truncate read, start new write burst
		} else if (bank[a_bank].state == BANK_ACTIVE) {
			// cancel any r/w, start new
			if (sdram.state != BANK_IDLE) {
				unsigned n = sdram.bankno;
				if (sdram.ap) {
					bank[n].state = BANK_PRECHARGE;
					bank[n].busy = tRP - 1; // ? tWR
				} else {
					bank[n].state = BANK_ACTIVE;
				}
			}
		} else {
			printf("sdram: bank%d cannot WRITE from state %s\n", a_bank, SN(a_bank));
			return -1;
		}
		if (ctl == CMD_WRITE) {
			bank[a_bank].state = BANK_WRITE;
			sdram.state = BANK_WRITE;
			sdram.count = sdram.wr_burst;
		} else {
			bank[a_bank].state = BANK_READ;
			sdram.state = BANK_READ;
			sdram.count = sdram.rd_burst;
		}
		sdram.bankno = a_bank;
		sdram.addr = ADDR(a_bank, bank[a_bank].rowaddr, a_col);
		sdram.count = sdram.wr_burst;
		sdram.ap = a_a10; // CHECK
		break;
	case CMD_STOP:
		if ((sdram.state == BANK_READ) || (sdram.state == BANK_WRITE)) {
			unsigned n = sdram.bankno;
			sdram.state = BANK_IDLE;
			if (sdram.ap) {
				// TODO: double-check this is corrcet to honor
				bank[n].state = BANK_PRECHARGE;
				bank[n].busy = tRP - 1;
			} else {
				bank[n].state = BANK_ACTIVE;
			}
		}
		break;
	case CMD_NOP:
		break;
	}

	// process active read or write operation
	if (sdram.state != BANK_IDLE) {
		if (sdram.state == BANK_WRITE) {
			memory[sdram.addr] = din;
		} else {
			sdram.pipe_data_o[0] = memory[sdram.addr];
			sdram.pipe_data_e[0] = 1;
		}
		sdram.count--;
		if (sdram.count == 0) {
			sdram.state = BANK_IDLE;
			if (sdram.ap) {
				bank[sdram.bankno].state = BANK_PRECHARGE;
				bank[sdram.bankno].busy = tRP - 1; // ? tWR
			} else {
				bank[sdram.bankno].state = BANK_ACTIVE;
			}
		} else {
			sdram.addr = (sdram.addr & (~COLMASK)) | ((sdram.addr + 1) & COLMASK);
		}
	}

done:
	return 0;
}


// TODO: DQM H = read: force dout to highz (2 cycles later)
//       DQM H = write: mask write
//
//       CKE / CS# - currently assumed always H and L
#endif
