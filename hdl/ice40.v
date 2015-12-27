// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module top(
	input clk,
	output [15:0]trace
	);

wire [15:0]waddr /* synthesis syn_keep=1 */;
wire [15:0]wdata /* synthesis syn_keep=1 */;
wire we /* synthesis syn_keep=1 */;
wire [15:0]raddr /* synthesis syn_keep=1 */;
wire [15:0]rdata /* synthesis syn_keep=1 */;
wire re /* synthesis syn_keep=1 */;

cpu #(
	.RWIDTH(16),
	.SWIDTH(4)
	)cpu0(
	.clk(clk),
	.mem_waddr_o(waddr),
	.mem_wdata_o(wdata),
	.mem_wr_o(we),
	.mem_raddr_o(raddr),
	.mem_rdata_i(rdata),
	.mem_rd_o(re)
	) /* synthesis syn_keep=1 */;

assign trace = waddr;

wire cs0r = ~raddr[8];
wire cs0w = ~waddr[8];
wire cs1r = raddr[8];
wire cs1w = waddr[8];

wire [15:0]rdata0;
wire [15:0]rdata1;

assign rdata = cs0r ? rdata0 : rdata1;

sram ram0(
	.clk(clk),
	.raddr(raddr),
	.rdata(rdata0),
	.re(re & cs0r),
	.waddr(waddr),
	.wdata(wdata),
	.we(we & cs0w)
	);

sram ram1(
	.clk(clk),
	.raddr(raddr),
	.rdata(rdata1),
	.re(re & cs0r),
	.waddr(waddr),
	.wdata(wdata),
	.we(we & cs0w)
	);

endmodule

module sram(
	input clk,
	input [15:0]raddr,
	output [15:0]rdata,
	input re,
	input [15:0]waddr,
	input [15:0]wdata,
	input we
	);

SB_RAM256x16 sram_inst(
	.RDATA(rdata),
	.RADDR(raddr[7:0]),
	.RCLK(clk),
	.RCLKE(1'b1),
	.RE(re),
	.WADDR(waddr[7:0]),
	.WDATA(wdata),
	.WCLK(clk),
	.WCLKE(1'b1),
	.WE(we)
	);

endmodule
