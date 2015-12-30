// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module alu #(
	parameter DWIDTH = 16,
	parameter SWIDTH = 4
	)(
	input [3:0]op,
	input [DWIDTH-1:0]adata,
	input [DWIDTH-1:0]bdata,
	output reg[DWIDTH-1:0]rdata
	);

`ifdef BIT_OPS
wire [DWIDTH-1:0]bits = (1 << bdata[SWIDTH-1:0]);
`endif

always @(*) begin
	case (op)
	4'b0000: rdata = bdata;
	4'b0001: rdata = adata & bdata;
	4'b0010: rdata = adata | bdata;
	4'b0011: rdata = adata ^ bdata;
	4'b0100: rdata = adata + bdata;
	4'b0101: rdata = adata - bdata;
	4'b0110: rdata = adata * bdata;
	4'b0111: rdata = { bdata[7:0], adata[7:0] };
	4'b1000: rdata = { {(DWIDTH-1){1'b0}}, adata < bdata };
	4'b1001: rdata = { {(DWIDTH-1){1'b0}}, adata <= bdata };
`ifdef FULL_SHIFTER
	4'b1010: rdata = adata >> bdata[SWIDTH-1:0];
	4'b1011: rdata = adata << bdata[SWIDTH-1:0];
`else
	4'b1010: rdata = { 1'b0, adata[DWIDTH-1:1] };
	4'b1011: rdata = { adata[DWIDTH-2:0], 1'b0 };
`endif
`ifdef BIT_OPS
	4'b1100: rdata = adata | bits;
	4'b1101: rdata = adata & (~bits);
	4'b1110: rdata = adata & bits;
	4'b1111: rdata = bits;
`else
	4'b1100: rdata = {DWIDTH{1'bX}};
	4'b1101: rdata = {DWIDTH{1'bX}};
	4'b1110: rdata = {DWIDTH{1'bX}};
	4'b1111: rdata = {DWIDTH{1'bX}};
`endif
	endcase
end

endmodule
