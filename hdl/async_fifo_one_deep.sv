// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// Based on the design described in
// "5.8.2 Multi-bit CDC signal passing using 1-deep / 2-register FIFO synchronizer"
// Clock Domain Crossing (CDC) Design & Verification Techniques
// http://www.sunburst-design.com/papers/CummingsSNUG2008Boston_CDC.pdf

module async_fifo_one_deep #(
	parameter WIDTH = 16
	)(
	input wire wr_clk,
	input wire wr_valid,
	input wire [WIDTH-1:0]wr_data,
	output wire wr_ready,
	input wire rd_clk,
	input wire rd_ready,
	output wire rd_valid,
	output wire [WIDTH-1:0]rd_data
);

// 2 register deep fifo storage
reg [WIDTH-1:0]fifo_reg_0 = 0;
reg [WIDTH-1:0]fifo_reg_1 = 0;

// wr domain registers
reg wr_ptr = 0;
reg wr_rd_ptr = 0;
reg wr_rd_ptr_sync = 0;

// writable (empty) when read and write pointers are the same
assign wr_ready = ~(wr_rd_ptr ^ wr_ptr);

always_ff @(posedge wr_clk) begin
	// sync rd_ptr into wr_ domain
	wr_rd_ptr_sync <= rd_ptr;
	wr_rd_ptr <= wr_rd_ptr_sync;

	// wr_ptr state machine
	wr_ptr <= (wr_valid & wr_ready) ^ wr_ptr;

	// fifo registers write control
	if (wr_valid & wr_ready) begin
		if (wr_ptr) begin
			fifo_reg_1 <= wr_data;
		end else begin
			fifo_reg_0 <= wr_data;
		end
	end
end

// fifo registers read control
assign rd_data = rd_ptr ? fifo_reg_1 : fifo_reg_0;

// rd domain registers
reg rd_ptr = 0;
reg rd_wr_ptr = 0;
reg rd_wr_ptr_sync = 0;

// readable (full) when read and write pointers are different
assign rd_valid = (rd_wr_ptr ^ rd_ptr);

always_ff @(posedge rd_clk) begin
	// sync wr_ptr into rd_ domain
	rd_wr_ptr_sync <= wr_ptr;
	rd_wr_ptr <= rd_wr_ptr_sync;

	// rd_ptr state machine
	rd_ptr <= (rd_valid & rd_ready) ^ rd_ptr; 
end

endmodule
