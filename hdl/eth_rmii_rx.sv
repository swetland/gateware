// Copyright 2014 Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

// CRS_DV -- multiplexed, CR on first di-bit, DV on second di-bit of each nibble
//
//           preamble | packet 
// crs_dv ... 1 1 1 1 1 CR DV CR DV CR DV CR ...
// rx0    ... 0 0 0 0 1 b0 b2 b4 b6 b0 b2 b4 ...
// rx1    ... 1 1 1 1 1 b1 b3 b5 b7 b1 b3 b5 ...
//
// CR can go low when carrier lost, while DV remains asserted through end of frame.

// valid is asserted on each clock where data contains a byte of the frame
// eop is asserted for one clock after the last byte of the frame has arrived
// and before the next frame's first byte arrives

module eth_rmii_rx(
	// 50MHz RMII clock
	input clk50,

	// RMII input
	input [1:0]rx,
	input crs_dv,

	// packet byte data output
	output reg [7:0]data = 0,

	// active when data is a valid byte (once every 4 clk50s during rx)
	output reg valid = 0,

	// active for a single clk50 before the first byte of a packet arrives
	output reg sop = 0,

	// active for a single clk50 after the last byte has arrived
	output reg eop = 0,
	
	// active as of eop and until sop, if packet crc32 is valid
	output reg crc_ok = 0,

	// transmit outputs which can drive
	// an eth_rmii_tx to create a repeater
	output reg [1:0]out_tx = 0,
	output reg out_txen = 0
	);

localparam IDLE = 4'd0;
localparam PRE1 = 4'd1;
localparam PRE2 = 4'd2;
localparam PRE3 = 4'd3;
localparam DAT0 = 4'd4;
localparam DAT1 = 4'd5;
localparam DAT2 = 4'd6;
localparam DAT3 = 4'd7;
localparam ERR0 = 4'd8;
localparam ERR1 = 4'd9;
localparam EOP = 4'd10;

reg [3:0]state = IDLE;
reg [3:0]next_state;

reg [7:0]next_data;
reg next_valid;
reg next_eop;

wire [7:0]rxshift = { rx, data[7:2] };

reg [1:0]delay_tx = 0;
reg delay_txen = 0;
reg next_txen;
reg next_sop;
reg next_crc_ok;

wire [31:0]crc;
reg crc_en;

eth_crc32_2 rx_crc(
	.clk(clk50),
	.en(crc_en),
	.rst(sop),
	.din(rx),
	.crc(crc)
);

always_comb begin
	next_state = state;
	next_data = data;
	next_valid = 0;
	next_eop = 0;
	next_sop = 0;
	next_txen = delay_txen;
	next_crc_ok = crc_ok;
	crc_en = 0;

	if (sop) begin
		// always mark crc invalid at start of packet
		next_crc_ok = 0;
	end else if (valid) begin
		// record crc validity after each byte is received
		// if we just leave it free-running, we end up shifting in
		// bogus data from after the FCS but before we observe DV
		// deasserting mid-byte
		next_crc_ok = (crc == 32'hdebb20e3);
	end

	case (state)
	IDLE: if ((rx == 2'b01) && (crs_dv == 1)) begin
		// crs_dv may go high asynchronously
		// only move to preamble on crs_dv AND a preamble di-bit
		next_state = PRE1;
		next_txen = 1;
		next_sop = 1;
	end
	PRE1: if (rx == 2'b01) begin
		next_state = PRE2;
	end else begin
		next_state = ERR0;
	end
	PRE2: if (rx == 2'b01) begin
		next_state = PRE3;
	end else begin
		next_state = ERR0;
	end
	PRE3: if (rx == 2'b11) begin
		next_state = DAT0;
	end else if (rx == 2'b01) begin
		next_state = PRE3;
	end else begin
		next_state = ERR0;
	end
	DAT0: begin
		next_data = rxshift;
		crc_en = 1'b1;
		next_state = DAT1;
	end
	DAT1: begin
		next_data = rxshift;
		crc_en = 1'b1;
		if (crs_dv) begin
			next_state = DAT2;
		end else begin
			next_txen = 0;
			next_state = EOP;
		end
	end
	DAT2: begin
		next_data = rxshift;
		crc_en = 1'b1;
		next_state = DAT3;
	end
	DAT3: begin
		next_data = rxshift;
		crc_en = 1'b1;
		if (crs_dv) begin
			next_state = DAT0;
			next_valid = 1;
		end else begin
			next_txen = 0;
			next_state = EOP;
		end
	end
	EOP: begin
		next_state = IDLE;
		next_data = 0;
		next_eop = 1;
	end
	ERR0: begin
		next_txen = 0;
		if (crs_dv == 0) begin
			next_state = ERR1;
		end
	end
	ERR1: begin
		if (crs_dv == 0) begin
			next_state = IDLE;
		end else begin
			next_state = ERR0;
		end
	end
	default: begin
		next_state = IDLE;
	end
	endcase
end

always_ff @(posedge clk50) begin
	state <= next_state;
	valid <= next_valid;
	data <= next_data;
	eop <= next_eop;
	sop <= next_sop;
	delay_txen <= next_txen;
	delay_tx <= rx;
	out_txen <= next_txen ? delay_txen : 0;
	out_tx <= next_txen ? delay_tx : 0;
	crc_ok <= next_crc_ok;
end

endmodule
