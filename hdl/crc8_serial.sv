// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

// 0x9C 10011100x // koopman notation (low bit implied)
// 0x39 x00111001 // truncated notation (high bit implied)

module crc8_serial(
	input clk,
	input din,
	input en,
	input rst,
	output [7:0]crc
	);

reg [7:0]r;

wire d = din ^ r[7];

always @(posedge clk) begin
	if (rst) begin
		r <= 8'hFF;
	end else if (en) begin
		r[0] <= d;
		r[1] <= r[0];
		r[2] <= r[1];
		r[3] <= r[2] ^ d;
		r[4] <= r[3] ^ d;
		r[5] <= r[4] ^ d;
		r[6] <= r[5];
		r[7] <= r[6];
	end
end

assign crc = { r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7] };

endmodule

