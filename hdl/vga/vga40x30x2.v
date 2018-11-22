// Copyright 2012, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

module vga40x30x2(
	input clk25m,
	output [1:0]red,
	output [1:0]grn,
	output [1:0]blu,
	output hs,
	output vs,
	output fr,
	input vram_clk,
	input [10:0]vram_waddr,
	input [7:0]vram_wdata,
	input vram_we
	);

wire [3:0]r;
wire [3:0]g;
wire [3:0]b;

wire newline;
wire advance;
wire [7:0]line;
wire[11:0]pixel;

vga vga0(
	.clk(clk25m),
	.hs(hs),
	.vs(vs),
	.fr(fr),
	.r(r),
	.g(g),
	.b(b),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel)
	);

assign red = r[3:2];
assign grn = g[3:2];
assign blu = b[3:2];

wire [10:0]vram_raddr;
wire [7:0]vram_rdata;

pixeldata pixeldata0(
	.clk(clk25m),
	.newline(newline),
	.advance(advance),
	.line(line),
	.pixel(pixel),
	.vram_data(vram_rdata),
	.vram_addr(vram_raddr)
	);

videoram #(8,11) vram(
	.rclk(clk25m),
	.re(1'b1),
	.rdata(vram_rdata),
	.raddr(vram_raddr),
	.wclk(vram_clk),
	.we(vram_we),
	.wdata(vram_wdata[7:0]),
	.waddr(vram_waddr[10:0])
	);

endmodule
