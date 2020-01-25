// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

`timescale 1ns / 1ps

`define HEX_PATHS

module testbench(
        input clk,
	output [3:0]vga_red,
	output [3:0]vga_grn,
	output [3:0]vga_blu,
	output vga_hsync,
	output vga_vsync,
	output vga_frame,
	output reg error = 0,
	output reg done = 0
        );

display #(
	.BPP(4),
	)vga(
	.clk(clk),
	.red(vga_red),
	.grn(vga_grn),
	.blu(vga_blu),
	.hsync(vga_hsync),
	.vsync(vga_vsync),
	.frame(vga_frame),
	.active(),
	.waddr(12'b0),
	.wdata(16'b0),
	.we(1'b0),
	.wclk(clk)
	);

endmodule
