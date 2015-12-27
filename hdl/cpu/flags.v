// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module check_cond(
	input [3:0]flags_i,
	input [3:0]cond_i,
	output reg is_true_o
	);

	wire N = flags_i[3];
	wire Z = flags_i[2];
	wire C = flags_i[1];
	wire V = flags_i[0];
	
always @(*)
	case (cond_i)
	4'b0000: is_true_o = Z;			// eq|z
	4'b0001: is_true_o = !Z;		// ne|nz
	4'b0010: is_true_o = C;			// cs|hs
	4'b0011: is_true_o = !C;		// cc|lo
	4'b0100: is_true_o = N;			// mi
	4'b0101: is_true_o = !N;		// pl
	4'b0110: is_true_o = V;			// vs
	4'b0111: is_true_o = !V;		// vc
	4'b1000: is_true_o = V && !Z;		// hi
	4'b1001: is_true_o = !V || Z;		// ls
	4'b1010: is_true_o = N == V;		// ge
	4'b1011: is_true_o = N != V;		// lt
	4'b1100: is_true_o = !Z && (N == V);	// gt
	4'b1101: is_true_o = Z || (N != V);	// le
	4'b1110: is_true_o = 1;			// al
	4'b1111: is_true_o = 0;			// nv
	endcase
endmodule


