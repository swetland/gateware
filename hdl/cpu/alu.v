// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

`define MINIMAL_ALU

module alu(
	input [3:0]op,
	input [DWIDTH-1:0]adata,
	input [DWIDTH-1:0]bdata,
	output reg [DWIDTH-1:0]rdata,
	input [3:0]flags_i,
	output [3:0]flags_o
	);

parameter DWIDTH = 16;
parameter SWIDTH = 4;

wire a_neg = adata[DWIDTH-1];
wire b_neg = bdata[DWIDTH-1];
wire r_neg = rdata[DWIDTH-1];

wire N = r_neg;
wire Z = (rdata == {DWIDTH{1'b0}});
wire C = (a_neg & b_neg) || ((a_neg & b_neg) && !r_neg);
wire V = !(a_neg ^ b_neg) && (a_neg ^ r_neg);

`ifndef MINIMAL_ALU
wire [DWIDTH-1:0]carry = {{(DWIDTH-1){1'b0}}, (flags_i[1] & op[3])};
wire [DWIDTH-1:0]add = adata + bdata + carry;
wire [DWIDTH-1:0]sub = adata - bdata - carry;
wire [DWIDTH-1:0]bits = (1 << bdata[SWIDTH-1:0]);
`endif

reg nz;
reg cv;

`ifdef MINIMAL_ALU
always @(*) begin
	case (op[2:0])
	3'b000: begin nz = 1'b0; cv = 1'b0; rdata = bdata; end
	3'b001: begin nz = 1'b1; cv = 1'b0; rdata = adata & bdata; end
	3'b010: begin nz = 1'b1; cv = 1'b0; rdata = adata | bdata; end
	3'b011: begin nz = 1'b1; cv = 1'b0; rdata = adata ^ bdata; end
	3'b100: begin nz = 1'b1; cv = 1'b1; rdata = adata + bdata; end
	3'b101: begin nz = 1'b1; cv = 1'b1; rdata = adata - bdata; end
	3'b110: begin nz = 1'b1; cv = 1'b0; rdata = bdata << 1; end
	3'b111: begin nz = 1'b1; cv = 1'b0; rdata = bdata >> 1; end
	endcase
end
`else
always @(*) begin
	case (op)
	4'b0000: begin nz = 1'b0; cv = 1'b0; rdata = bdata; end
	4'b0001: begin nz = 1'b1; cv = 1'b0; rdata = adata & bdata; end
	4'b0010: begin nz = 1'b1; cv = 1'b0; rdata = adata | bdata; end
	4'b0011: begin nz = 1'b1; cv = 1'b0; rdata = adata ^ bdata; end
	4'b0100: begin nz = 1'b1; cv = 1'b1; rdata = add; end
	4'b0101: begin nz = 1'b1; cv = 1'b1; rdata = sub; end
	4'b0110: begin nz = 1'b1; cv = 1'b0; rdata = bdata << 1; end
	4'b0111: begin nz = 1'b1; cv = 1'b0; rdata = bdata >> 1; end
	4'b1000: begin nz = 1'b1; cv = 1'b1; rdata = add; end // adc
	4'b1001: begin nz = 1'b1; cv = 1'b1; rdata = sub; end // sbc
	4'b1010: begin nz = 1'b1; cv = 1'b0; rdata = bdata << 4; end
	4'b1011: begin nz = 1'b1; cv = 1'b0; rdata = bdata >> 4; end
	4'b1100: begin nz = 1'b1; cv = 1'b0; rdata = adata | bits; end // bis
	4'b1101: begin nz = 1'b1; cv = 1'b0; rdata = adata & (~bits); end // bic
	4'b1110: begin nz = 1'b1; cv = 1'b0; rdata = adata & bits; end // tbs
	4'b1111: begin nz = 1'b1; cv = 1'b0; rdata = adata * bdata; end
	endcase
end
`endif

assign flags_o[3] = nz ? N : flags_i[3];
assign flags_o[2] = nz ? Z : flags_i[2];
assign flags_o[1] = cv ? C : flags_i[1];
assign flags_o[0] = cv ? V : flags_i[0];
endmodule
