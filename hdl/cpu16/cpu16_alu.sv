// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module cpu16_alu(
	input reg [3:0]op,
	input reg [15:0]x,
	input reg [15:0]y,
	output reg [15:0]r
	);

always_comb begin
	case (op)
	4'b0000: r = x & y;
	4'b0001: r = x | y;
	4'b0010: r = x ^ y;
	4'b0011: r = ~x;
	4'b0100: r = x + y;
	4'b0101: r = x - y;
	4'b0110: r = { 15'd0, $signed(x) < $signed(y) };
	4'b0111: r = { 15'd0, x < y };
	4'b1000: r = y[0] ? {x[11:0], 4'b0} : {x[14:0], 1'b0}; // SHL 4 or 1
	4'b1001: r = y[0] ? {4'b0, x[15:4]} : {1'b0, x[15:1]}; // SHR 4 or 1
	4'b1010: r = y[0] ? {x[11:0], x[15:12]} : {x[14:0], x[15]}; // ROL 4 or 1
	4'b1011: r = y[0] ? {x[3:0], x[15:4]} : {x[0], x[15:1]}; // ROR 4 or 1
	4'b1100: r = x * y;
	4'b1101: r = { x[7:0], y[7:0] };
	4'b1110: r = { x[7:0], y[15:8] };
	4'b1111: r = { y[5:0], x[9:0] };
	endcase
end

endmodule
