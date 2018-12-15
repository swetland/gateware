// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// Assumes clk is 12M and baudrate is 1M
// TODO: parameterize this a bit

module uart_rx(
	input clk,
	input rx,
	output [7:0]data,
	output ready,
	output crc_din,
	output crc_en
);	

// active indicates reception in progress
reg active = 1'b0;
reg active_next;

// bitcount is a downcounter of bits remaining to receive
reg [2:0]bitcount = 3'd0;
reg [2:0]bitcount_next;

wire bitcount_done;
wire [2:0]bitcount_minus_one;
assign { bitcount_done, bitcount_minus_one } = { 1'b0, bitcount } - 4'd1;

// tickcount is a downcounter of sys_clk ticks until next bit
reg [3:0]tickcount = 4'd0;
reg [3:0]tickcount_next;

wire tick;
wire [3:0]tickcount_minus_one;
assign { tick, tickcount_minus_one }  = { 1'b0, tickcount } - 5'd1;

// receive shift register
reg [7:0]rxdata;
reg [7:0]rxdata_next;

// most recent 3 bits for edge detection
reg [2:0]rxedge;

// drives the ready flag
reg signal = 1'b0;
reg signal_next;

assign data = rxdata;
assign ready = signal;

// pass inbound bits to serial crc engine
assign crc_din = rxedge[2];
assign crc_en = active & tick;

always_comb begin
	signal_next = 1'b0;
	active_next = active;
	bitcount_next = bitcount;
	tickcount_next = tickcount;
	rxdata_next = rxdata;

	if (active) begin
		if (tick) begin
			rxdata_next = { rxedge[2], rxdata[7:1] };
			if (bitcount_done) begin
				active_next = 1'b0;
				signal_next = 1'b1;
			end else begin
				bitcount_next = bitcount_minus_one;
				// 12 (-1) ticks to the next bit center
				tickcount_next = 4'd11;
			end
		end else begin
			tickcount_next = tickcount_minus_one;
		end
	end else begin
		if (rxedge == 3'b001) begin
			// 12 ticks center to center + 4 to adjust from
			// 2 ticks into the start bit = 16 (-1):
			tickcount_next = 4'd15;
			// 8 (-1) bits to receive:
			bitcount_next = 3'd7;
			// start!
			active_next = 1'b1;
		end
	end
end

always_ff @(posedge clk) begin
	rxedge <= { rx, active ? 2'b0 : rxedge[2:1] };
	rxdata <= rxdata_next;
	signal <= signal_next;
	active <= active_next;
	bitcount <= bitcount_next;
	tickcount <= tickcount_next;
end

endmodule
