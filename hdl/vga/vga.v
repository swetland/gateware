// Copyright 2012, Brian Swetland

`timescale 1ns/1ns

// Vert:  2xSync 30xBack 480xData 12xFront  -> 524 lines
// Horz: 96xSync 48xBack 640xData 16xFront  -> 800 pixels
//
// CLK: 25MHz, px=40nS, line=32uS, frame=16.768mS

module vga(
	input clk,
	output hs,
	output vs,
	output fr,
	output [3:0] r,
	output [3:0] g,
	output [3:0] b,

	output newline,
	output advance,
	output [7:0] line,
	input [11:0] pixel
	);

reg hsync = 1'b0;
reg vsync = 1'b0;
reg frame = 1'b0;
reg active = 1'b0;
reg startline = 1'b0;
reg [9:0] hcount = 10'b0;
reg [9:0] vcount = 10'b0;

reg next_hsync;
reg next_vsync;
reg next_frame;
reg next_active;
reg next_startline;
reg [9:0] next_hcount;
reg [9:0] next_vcount;
reg [9:0] next_lineno;
reg [7:0] lineno;

assign hs = hsync;
assign vs = vsync;
assign fr = frame;
assign line = lineno;
assign advance = active;
assign newline = startline;

assign r = active ? pixel[11:8] : 4'd0;
assign g = active ? pixel[7:4] : 4'd0;
assign b = active ? pixel[3:0] : 4'd0;

always_comb begin
	next_hsync = 1'b0;
	next_vsync = 1'b0;
	next_frame = 1'b0;
	next_hcount = 10'd0;
	next_vcount = 10'd0;
	next_active = 1'b0;
	next_startline = 1'b0;
	next_lineno = 10'b0;

	if (hcount == 10'd799) begin
		if (vcount == 10'd523) begin
			next_vcount = 10'd0;
			next_frame = 1'b1;
		end else
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
		next_hsync = 1'b0;
	else
		next_hsync = 1'b1;

	if (next_vcount < 10'd2)
		next_vsync = 1'b0;
	else
		next_vsync = 1'b1;

	if ((next_vcount > 31) && (next_vcount < 512))
		if ((next_hcount > 143) && (next_hcount < 784))
			next_active = 1'b1;

	next_lineno = next_vcount - 10'd32;
end

always_ff @(posedge clk) begin
	hcount <= next_hcount;
	vcount <= next_vcount;
	hsync <= next_hsync;
	vsync <= next_vsync;
	frame <= next_frame;

	/* signals to pixel generator */
	startline <= next_startline;
	active <= next_active;
	lineno <= next_lineno[8:1];
end

endmodule
