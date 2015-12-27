// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

// more like a UAT at the moment...

`timescale 1ns/1ns

module uart(
	input clk,
	input [7:0]wdata,
	output [7:0]rdata,
	output busy,
	input we,
	output tx
	);

parameter DIVISOR = 416;

reg out = 1'b1;
reg busy = 0'b1;
reg [7:0] data = 8'hFF;
reg [3:0] state = 4'b0010;
wire next_bit;

uart_bit_counter counter(
	.clk(clk),
	.max(DIVISOR),
	.overflow(next_bit)
	);

assign tx = out;
assign rdata = { 7'b0, busy };

always @(posedge clk) begin
	if (!busy) begin
		if (we) begin
			data <= wdata;
			busy <= 1'b1;
		end
	end else if (next_bit) begin
		case (state)
		4'b0000: begin state <= busy ? 4'b0001 : 4'b0000; out <= 1'b1; end
		4'b0001: begin state <= 4'b0010; out <= 1'b0; end
		4'b0010: begin state <= 4'b0011; out <= data[0]; end
		4'b0011: begin state <= 4'b0100; out <= data[1]; end
		4'b0100: begin state <= 4'b0101; out <= data[2]; end
		4'b0101: begin state <= 4'b0110; out <= data[3]; end
		4'b0110: begin state <= 4'b0111; out <= data[4]; end
		4'b0111: begin state <= 4'b1000; out <= data[5]; end
		4'b1000: begin state <= 4'b1001; out <= data[6]; end
		4'b1001: begin state <= 4'b1010; out <= data[7]; end
		4'b1010: begin state <= 4'b1011; out <= 1'b1; end
		4'b1011: begin state <= 4'b0000; out <= 1'b1; busy <= 1'b0; end
		endcase
	end
end

endmodule

module uart_bit_counter(
	input clk,
	input [15:0] max,
	output overflow
	);

reg [15:0] count = 16'b0;

assign overflow = (count == max);

always @(posedge clk) begin
	count <= overflow ? 16'b0 : (count + 16'b1);
end

endmodule


