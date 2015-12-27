// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module testbench(
	input clk
	);

reg [15:0]count = 16'd0;

always @(posedge clk) begin
	count <= count + 16'd1;
	if (count == 16'hFFFF) $finish;
end

wire [15:0]wdata;
wire [15:0]waddr;
wire [15:0]raddr;
wire [15:0]rdata;
wire wr;
wire rd;

simram dram(
	.clk(clk),
	.waddr(waddr),
	.wdata(wdata),
	.we(wr),
	.raddr(raddr),
	.rdata(rdata),
	.re(rd)
	);

cpu 
`ifdef BIGCPU
	#(
	.RWIDTH(32),
	.SWIDTH(5)
	)
`endif
	cpu0(
	.clk(clk),
	.mem_raddr_o(raddr),
	.mem_rdata_i(rdata),
	.mem_waddr_o(waddr),
	.mem_wdata_o(wdata),
	.mem_wr_o(wr),
	.mem_rd_o(rd)
	);

endmodule
