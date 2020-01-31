// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module testbench(
	input wire clk,
	output reg error = 0,
	output reg done = 0
);

wire [31:0]wr_data;
wire wr_ready;
reg wr_valid = 0;

wire [31:0]rd_data;
wire rd_valid;
reg rd_ready = 0;

wire [31:0]chk_data;

reg [31:0]count = 0;
reg [31:0]rd_count = 0;

// pattern of writes and reads to issue
reg[63:0]w0 = 64'b0001011111111000000000000001111111111111111111111111111111111111;
reg[63:0]r0 = 64'b0000000000000001111111111000000000000000000000010001111111111111;

reg[63:0]w1 = 64'b1111100000000000000000000001111111111111111111111111111111111111;
reg[63:0]r1 = 64'b1111111111100011111111111111111111111111111111101010011000111111;

reg[63:0]w2 = 64'b1111111000000000000000010110001111111111111111100000000000000000;
reg[63:0]r2 = 64'b1111111111111111111111111111111111111111111000100000011111110000;

reg[63:0]w3 = 64'b0000000001000100011000010011100000010101111000000101011011000000;
reg[63:0]r3 = 64'b0000000001010010100101001101001111010101111111100101010100111111;

reg[63:0]w4 = 64'b1111100000000000000000000000000000000000000000000000000000000000;
reg[63:0]r4 = 64'b1111100000000000000000000000000000000000000000000000000000000000;

reg[319:0]writes = { w0, w1, w2, w3, w4 };
reg[319:0]reads = { r0, r1, r2, r3, r4 };

always_ff @(posedge clk) begin
	$display("%3d: W(%08x) %s %s --> R(%08x) %s %s   C(%08x)  RX(%3d)",
		count,
		wr_data, wr_valid ? "V" : "-", wr_ready ? "r" : "-",
		rd_data, rd_valid ? "v" : "-", rd_ready ? "R" : "-",
		chk_data, rd_count);

	count <= count + 32'd1;
	writes <= { writes[318:0], 1'b0 };
	reads <= { reads[318:0], 1'b0 };
	rd_ready <= reads[319];
	wr_valid <= writes[319];

	if (rd_valid & rd_ready) begin
		rd_count <= rd_count + 32'd1;
		if (rd_data != chk_data) begin
			error <= 1;
			$display("%3d: rd_data(%08x) != chk_data(%08x)",
				count, rd_data, chk_data);
		end	
	end

	if (rd_count == 128) done <= 1;
	if (count == 32'd500) error <= 1;
end

sync_fifo #(
	.WIDTH(32),
	.DEPTH(4)
	) fifo (
	.clk(clk),
	.wr_data(wr_data),
	.wr_valid(wr_valid),
	.wr_ready(wr_ready),
	.rd_data(rd_data),
	.rd_valid(rd_valid),
	.rd_ready(rd_ready)
);

// write data stream
// cue up a new value next clock, whenever
// the current value would have been accepted
xorshift32 xs32wr (
	.clk(clk),
	.next(wr_valid & wr_ready),
	.data(wr_data),
	.reset(0)
);

// read verification data stream
// cue up a new value next clock, whenever
// the current value would have been checked
xorshift32 xs32rd (
	.clk(clk),
	.next(rd_valid & rd_ready),
	.data(chk_data),
	.reset(0)
);

endmodule
