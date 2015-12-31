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

#ifndef _FTDI_H_
#define _FTDI_H_

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;

#define FTDI_GPIO_READ_LO		0x81
#define FTDI_GPIO_READ_HI		0x83
#define FTDI_GPIO_WRITE_LO		0x80 // Val Dir  (1=Out 0=In)
#define FTDI_GPIO_WRITE_HI		0x82 // Val Dir  (1=Out 0=In)

#define FTDI_LOOPBACK_OFF		0x85
#define FTDI_CLOCK_DIV_1		0x8A
#define FTDI_CLOCK_DIV_5		0x8B
#define FTDI_DIVISOR_SET		0x86

// TN = TX on Negative Clock Edge
// TP = TX on Positive CLock Edge
// byte transfers followed by LenLo LenHi (len-1) then data
#define FTDI_MSB_TX_BYTES_TP		0x10
#define FTDI_MSB_TX_BYTES_TN		0x11 //
#define FTDI_MSB_IO_BYTES_TN_RP		0x31 //
#define FTDI_MSB_IO_BYTES_TP_RN		0x34

#define FTDI_LSB_TX_BYTES_TP		0x18
#define FTDI_LSB_TX_BYTES_TN		0x19
#define FTDI_LSB_IO_BYTES_TN_RP		0x39
#define FTDI_LSB_IO_BYTES_TP_RN		0x3C

typedef struct FTDI FTDI;

FTDI *ftdi_open(void);
int ftdi_read(FTDI *d, unsigned char *data, int count, int timeout_ms);
int ftdi_send(FTDI *ftdi, void *data, int len, int timeout_ms);

int ftdi_gpio_set_lo(FTDI *d, u8 val, u8 out);
int ftdi_gpio_get_lo(FTDI *d);

#endif
