// Copyright 2012, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module vga40x30x2 #(
	parameter BPP = 2,
	parameter RGB = 0
)(
	input clk25m,
	output [BPP-1:0]red,
	output [BPP-1:0]grn,
	output [BPP-1:0]blu,
	output hs,
	output vs,
	output fr,
	output active,
	input vram_clk,
	input [10:0]vram_waddr,
	input [15:0]vram_wdata,
	input vram_we
);

wire newline;
wire advance;
wire [7:0]line;
wire [(3*BPP)-1:0]pixel;

vga #(
	.BPP(BPP)
	) vga0 (
	.clk(clk25m),
	.hs(hs),
	.vs(vs),
	.fr(fr),
	.r(red),
	.g(grn),
	.b(blu),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel)
	);

assign active = advance;

wire [10:0]vram_raddr;
wire [(RGB*8)+7:0]vram_rdata;

pixeldata #(
	.BPP(BPP),
	.RGB(RGB)
	) pixeldata0 (
	.clk(clk25m),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel),
	.vram_data(vram_rdata),
	.vram_addr(vram_raddr)
	);

videoram #((RGB*8)+8,11) vram(
	.rclk(clk25m),
	.re(1'b1),
	.rdata(vram_rdata),
	.raddr(vram_raddr),
	.wclk(vram_clk),
	.we(vram_we),
	.wdata(vram_wdata[(RGB*8)+7:0]),
	.waddr(vram_waddr[10:0])
	);

endmodule
