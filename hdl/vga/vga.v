// Copyright 2012, Brian Swetland

`timescale 1ns/1ns

// Vert:  2xSync 30xBack 480xData 12xFront  -> 524 lines
// Horz: 96xSync 48xBack 640xData 16xFront  -> 800 pixels
//
// CLK: 25MHz, px=40nS, line=32uS, frame=16.768mS

module vga(
	input clk,
	output reg hs,
	output reg vs,
	output reg [3:0] r,
	output reg [3:0] g,
	output reg [3:0] b,

	output reg newline,
	output reg advance,
	output reg [7:0] line,
	input [11:0] pixel
	);

reg [9:0] hcount;
reg [9:0] vcount;

reg [9:0] next_hcount;
reg [9:0] next_vcount;
reg next_hs, next_vs;
reg active;
reg next_startline;
reg [9:0] next_line;

always @* begin
	if (hcount == 10'd799) begin
		if (vcount == 10'd523)
			next_vcount = 10'd0;
		else
			next_vcount = vcount + 10'd1;
		next_hcount = 10'd0;
	end else begin
		next_vcount = vcount;
		next_hcount = hcount + 10'd1;
	end

	if (next_hcount == 0)
		next_startline = 1'b1;
	else
		next_startline = 1'b0;

	if (next_hcount < 10'd96)
		next_hs = 1'b0;
	else
		next_hs = 1'b1;

	if (next_vcount < 10'd2)
		next_vs = 1'b0;
	else
		next_vs = 1'b1;

	active = 1'b0;
	if ((next_vcount > 31) && (next_vcount < 512))
		if ((next_hcount > 143) && (next_hcount < 784))
			active = 1'b1;

	next_line = next_vcount - 10'd32;
end

always @(posedge clk) begin
	hcount <= next_hcount;
	vcount <= next_vcount;
	hs <= next_hs;
	vs <= next_vs;

	/* signals to pixel generator */
	newline <= next_startline;
	advance <= active;
	line <= next_line[8:1];

	if (active) begin
		r <= pixel[11:8];
		g <= pixel[7:4];
		b <= pixel[3:0];
	end else begin
		r <= 4'd0;
		g <= 4'd0;
		b <= 4'd0;
	end
end

endmodule
