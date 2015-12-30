// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module regfile #(
	parameter AWIDTH = 4,
	parameter DWIDTH = 16
	)(
	input clk,
	input [AWIDTH-1:0]asel,
	input [AWIDTH-1:0]bsel,
	input [AWIDTH-1:0]wsel,
	input wreg,
	output [DWIDTH-1:0]adata,
	output [DWIDTH-1:0]bdata,
	input [DWIDTH-1:0]wdata
	);

reg [DWIDTH-1:0] R[0:((1<<AWIDTH)-1)];

always @(posedge clk) begin
	if (wreg)
		R[wsel] <= wdata;
end
assign adata = R[asel];
assign bdata = R[bsel];

endmodule
