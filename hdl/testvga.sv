// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

`define HEX_PATHS

module testbench(
        input clk,
	output [3:0]vga_red,
	output [3:0]vga_grn,
	output [3:0]vga_blu,
	output vga_hsync,
	output vga_vsync,
	output vga_frame
        );

wire [1:0]red;
wire [1:0]grn;
wire [1:0]blu;

vga40x30x2 vga(
	.clk25m(clk),
	.red(red),
	.grn(grn),
	.blu(blu),
	.hs(vga_hsync),
	.vs(vga_vsync),
	.fr(vga_frame),
	.vram_waddr(11'b0),
	.vram_wdata(8'b0),
	.vram_we(1'b0),
	.vram_clk(clk)
	);

assign vga_red = { red, red[0], red[0] };
assign vga_grn = { grn, grn[0], grn[0] };
assign vga_blu = { blu, blu[0], blu[0] };

endmodule
