// Copyright 2020 Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module eth_rgmii_rx (
	// 2.5MHz / 25MHz / 125MHz RGMII clock
	input wire rx_clk,
	
	// RGMII input
	input wire pin_rx_dv,
	input wire [3:0]pin_rx_data,

	// Packet byte data output
	output reg [7:0] data = 0,

	// Active when data is a valid byte
	output reg valid = 0,

	// Active for one rx_clk cycle when start of packet detected
	// (start of preamble).  Typically 8 rx_clk's before the first
	// valid data byte arrives.
	output reg sop = 0,
	
	// Active for one rx_clk cycle when the packet has ended
	// (*after) the last valid data byte arrives
	output reg eop = 0,
	
	// Active when eop is active if packet FCS was valid
	output reg crc_ok = 0
);

// NOTES:
// 1. This is only functional for 1Gbe rates (125MHz clock) at present
// 2. It considers any packet preamble consisting of one or more 0x55s
//    and ending with an 0xD5 valid

wire rx_dv;
wire rx_err;
wire [7:0]rx_data;

// hardware-specific io buffers, delays, etc.
eth_rgmii_rx_glue glue (
	.rx_clk(rx_clk),
	.pin_rx_dv(pin_rx_dv),
	.pin_rx_data(pin_rx_data),
	.rx_dv(rx_dv),
	.rx_err(rx_err),
	.rx_data(rx_data)
);

wire [31:0]crc;

localparam IDLE = 2'd0;
localparam PREAMBLE = 2'd1;
localparam PACKET = 2'd2;
localparam INVALID = 2'd3;

reg [1:0]state = IDLE;
reg [1:0]next_state;
reg next_valid;
reg [7:0]next_data;
reg next_sop;
reg next_eop;
reg next_crc_ok;
reg crc_en;

always_comb begin
	next_state = state;
	next_data = data;
	next_valid = 1'b0;
	next_sop = 1'b0;
	next_eop = 1'b0;
	next_crc_ok = crc_ok;
	crc_en = 1'b0;

	case (state)
	IDLE: if (rx_dv) begin
		if (rx_data != 8'h55) begin
			next_state = INVALID;
		end else begin
			next_state = PREAMBLE;
			next_crc_ok = 1'b0;
			next_sop = 1'b1;
		end
	end
	PREAMBLE: begin // .. 55 55 55 D5 
		if (rx_data == 8'hD5) begin
			next_state = PACKET;
		end else if (rx_data != 8'h55) begin
			next_state = INVALID;
		end
	end
	PACKET: begin
		if (rx_dv == 1'b1) begin
			crc_en = 1'b1;
			next_data = rx_data;
			next_valid = 1'b1;
		end else begin
			next_crc_ok = (crc == 32'hDEBB20E3);
			next_eop = 1'b1;
			next_state = IDLE;
		end
	end
	INVALID: if (rx_dv == 1'b0) begin
		next_state = IDLE;
	end
	endcase
end

always_ff @(posedge rx_clk) begin
	state <= next_state;
	data <= next_data;
	valid <= next_valid;
	sop <= next_sop;
	eop <= next_eop;
	crc_ok <= next_crc_ok;
end

eth_crc32_8 crc32(
	.clk(rx_clk),
	.en(crc_en),
	.rst(sop),
	.din(rx_data),
	.crc(crc)
);

endmodule
