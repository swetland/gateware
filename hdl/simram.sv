// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

import "DPI-C" function void dpi_mem_write(int addr, int data);
import "DPI-C" function void dpi_mem_read(int addr, output int data);

module simram(
	input clk,
	input [15:0]waddr,
	input [15:0]wdata,
	input we,
	input [15:0]raddr,
	output reg [15:0]rdata,
	input re
	);

	wire [31:0]rawdata;
	wire [31:0]junk;

	// hack: this should be posedge but if we do that
	// then the dpi_mem_write() happens too early
	always @(negedge clk) begin
		if (we) begin
			$display(":WRI %08x %08x", waddr, wdata);
			dpi_mem_write({16'd0, waddr}, {16'd0, wdata});
		end
	end
	always @(posedge clk) begin
		if (re) begin
			dpi_mem_read({16'd0, raddr}, rawdata);
			rdata <= rawdata[15:0];
		end else begin
			//junk = $random();
			//rdata <= junk[15:0];
			rdata <= 16'hEEEE;
		end
	end
endmodule
