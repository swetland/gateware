// Copyright 2012, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

`timescale 1ns/1ns

// Vert:  2xSync 30xBack 480xData 12xFront  -> 524 lines
// Horz: 96xSync 48xBack 640xData 16xFront  -> 800 pixels
//
// CLK: 25MHz, px=40nS, line=32uS, frame=16.768mS

module vga #(
	parameter BPP = 4
)(
	input wire clk,
	output wire hs,
	output wire vs,
	output wire fr,
	output wire [BPP-1:0] r,
	output wire [BPP-1:0] g,
	output wire [BPP-1:0] b,

	output wire newline,
	output wire advance,
	output wire [7:0] line,
	input wire [(3*BPP)-1:0] pixel
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

wire [9:0] adjusted_vcount = next_vcount - 10'd32;

assign hs = hsync;
assign vs = vsync;
assign fr = frame;
assign line = adjusted_vcount[8:1];
assign advance = active;
assign newline = startline;

assign r = active ? pixel[(3*BPP)-1:(2*BPP)] : { BPP { 1'b0 }};
assign g = active ? pixel[(2*BPP)-1:BPP] : { BPP { 1'b0 }};
assign b = active ? pixel[BPP-1:0] : { BPP { 1'b0 }};

always_comb begin
	next_hsync = hsync;
	next_vsync = vsync;
	next_frame = 1'b0;
	next_active = 1'b0;
	next_startline = 1'b0;
	next_hcount = 10'd0;
	next_vcount = 10'd0;

	if (hcount == 10'd799) begin
		if (vcount == 10'd523) begin
			next_vcount = 10'd0;
			next_frame = 1'b1;
			next_vsync = 1'b0;
		end else
			next_vcount = vcount + 10'd1;
		next_hcount = 10'd0;
		next_hsync = 1'b0;
		next_startline = 1'b1;
	end else begin
		next_vcount = vcount;
		next_hcount = hcount + 10'd1;
	
		if (hcount == 10'd96)
			next_hsync = 1'b1;

		if (vcount == 10'd2)
			next_vsync = 1'b1;

		if ((vcount > 30) && (vcount < 511))
			if ((hcount > 142) && (hcount < 783))
				next_active = 1'b1;
	end

end

always_ff @(posedge clk) begin
	hsync <= next_hsync;
	vsync <= next_vsync;
	frame <= next_frame;
	active <= next_active;
	startline <= next_startline;
	hcount <= next_hcount;
	vcount <= next_vcount;
end

endmodule
