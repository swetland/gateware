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

#include "ftdi.h"

#include <libusb-1.0/libusb.h>

// FTDI MPSSE Device Info
static struct {
	u16 vid;
	u16 pid;
	u8 ep_in;
	u8 ep_out;
	const char *name;
} devinfo[] = {
	{ 0x0403, 0x6010, 0x81, 0x02, "ftdi" },
	{ 0x0403, 0x6014, 0x81, 0x02, "ftdi" },
	{ 0x0000, 0x0000, 0},
};

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

struct FTDI {
	struct libusb_device_handle *udev;
	u8 ep_in;
	u8 ep_out;
	u32 read_count;
	u32 read_size;
	u8 *read_ptr;
	u8 read_buffer[512];
};

#define FTDI_REQTYPE_OUT	(LIBUSB_REQUEST_TYPE_VENDOR \
	| LIBUSB_RECIPIENT_DEVICE | LIBUSB_ENDPOINT_OUT)
#define FTDI_CTL_RESET		0x00
#define FTDI_CTL_SET_BITMODE	0x0B
#define FTDI_CTL_SET_EVENT_CH	0x06
#define FTDI_CTL_SET_ERROR_CH	0x07

#define FTDI_IFC_A 1
#define FTDI_IFC_B 2

static int ftdi_reset(FTDI *d) {
	struct libusb_device_handle *udev = d->udev;
	if (libusb_control_transfer(udev, FTDI_REQTYPE_OUT, FTDI_CTL_RESET,
		0, FTDI_IFC_A, NULL, 0, 10000) < 0) {
		fprintf(stderr, "ftdi: reset failed\n");
		return -1;
	}
	return 0;
}

static int ftdi_mpsse_enable(FTDI *d) {
	struct libusb_device_handle *udev = d->udev;
	if (libusb_control_transfer(udev, FTDI_REQTYPE_OUT, FTDI_CTL_SET_BITMODE,
		0x0000, FTDI_IFC_A, NULL, 0, 10000) < 0) {
		fprintf(stderr, "ftdi: set bitmode failed\n");
		return -1;
	}
	if (libusb_control_transfer(udev, FTDI_REQTYPE_OUT, FTDI_CTL_SET_BITMODE,
		0x020b, FTDI_IFC_A, NULL, 0, 10000) < 0) {
		fprintf(stderr, "ftdi: set bitmode failed\n");
		return -1;
	}
	if (libusb_control_transfer(udev, FTDI_REQTYPE_OUT, FTDI_CTL_SET_EVENT_CH,
		0, FTDI_IFC_A, NULL, 0, 10000) < 0) {
		fprintf(stderr, "ftdi: disable event character failed\n");
		return -1;
	}
	return 0;	
	if (libusb_control_transfer(udev, FTDI_REQTYPE_OUT, FTDI_CTL_SET_ERROR_CH,
		0, FTDI_IFC_A, NULL, 0, 10000) < 0) {
		fprintf(stderr, "ftdi: disable error character failed\n");
		return -1;
	}
	return 0;	
}

static int ftdi_init(FTDI *d) {
	struct libusb_device_handle *udev;
	int n;

	if (libusb_init(NULL) < 0) {
		fprintf(stderr, "ftdi_open: failed to init libusb\n");
		return -1;
	}
	for (n = 0; devinfo[n].name; n++) {
		udev = libusb_open_device_with_vid_pid(NULL,
			devinfo[n].vid, devinfo[n].pid);
		if (udev == 0)
	       		continue;
		libusb_detach_kernel_driver(udev, 0);
		if (libusb_claim_interface(udev, 0) < 0) {
			//TODO: close
			continue;
		}
		d->udev = udev;
		d->read_ptr = d->read_buffer;
		d->read_size = 512;
		d->read_count = 0;
		d->ep_in = devinfo[n].ep_in;
		d->ep_out = devinfo[n].ep_out;
		return 0;
	}
	fprintf(stderr, "ftdi_open: failed to find usb device\n");
	return -1;
}

static int usb_bulk(struct libusb_device_handle *udev,
	unsigned char ep, void *data, int len, unsigned timeout) {
	int r, xfer;
	r = libusb_bulk_transfer(udev, ep, data, len, &xfer, timeout);
	if (r < 0) {
		fprintf(stderr,"bulk: error: %d\n", r);
		return r;
	}
	return xfer;
}

/* TODO: handle smaller packet size for lowspeed version of the part */
/* TODO: multi-packet reads */
/* TODO: asynch/background reads */
int ftdi_read(FTDI *d, unsigned char *buffer, int count, int timeout) {
	int xfer;
	while (count > 0) {
		if (d->read_count >= count) {
			memcpy(buffer, d->read_ptr, count);
			d->read_count -= count;
			d->read_ptr += count;
			return 0;
		}
		if (d->read_count > 0) {
			memcpy(buffer, d->read_ptr, d->read_count);
			count -= d->read_count;
			buffer += d->read_count;
			d->read_count = 0;
		}
		xfer = usb_bulk(d->udev, d->ep_in, d->read_buffer, d->read_size, 1000);
		if (xfer < 0)
			return -1;
		if (xfer < 2)
			return -1;
		/* discard header */
		d->read_ptr = d->read_buffer + 2;
		d->read_count = xfer - 2;
	}
	return 0;
}


FTDI *ftdi_open(void) {
	FTDI *d;
	if ((d = malloc(sizeof(FTDI))) == NULL) {
		return NULL;
	}
	if (ftdi_init(d))
		goto fail0;
	if (ftdi_reset(d))
		goto fail1;
	if (ftdi_mpsse_enable(d))
		goto fail1;
	return d;
fail1:
	libusb_close(d->udev);
fail0:
	// close?
	free(d);
	return NULL;
}

int ftdi_send(FTDI *d, void *data, int len, int timeout_ms) {
	return usb_bulk(d->udev, d->ep_out, data, len, timeout_ms);
}

int ftdi_gpio_set_lo(FTDI *d, u8 val, u8 out) {
	u8 cmd[3] = { FTDI_GPIO_WRITE_LO, val, out };
	return ftdi_send(d, cmd, 3, 1000);
}

int ftdi_gpio_get_lo(FTDI *d) {
	u8 cmd[1] = { FTDI_GPIO_READ_LO };
	if (ftdi_send(d, cmd, 1, 1000) < 0)
		return -1;
	if (ftdi_read(d, cmd, 1, 1000) < 0)
		return -1;
	return cmd[0];
}

