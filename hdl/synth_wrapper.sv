// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

// Inspired by Synthesis Harness Input / Output
// from Charles LaForest's FPGA Design Elements
// http://fpgacpu.ca/fpga/index.html

`default_nettype none

module synth_input_wrapper #(
	parameter WIDTH = 1
	)(
	input wire clk,
	input wire pin_in,
	input wire pin_valid,
	(* keep="true" *) output reg [WIDTH-1:0]din = 0
);

always @(posedge clk)
	if (pin_valid)
		din <= { pin_in, din[WIDTH-1:1] };

endmodule

module synth_output_wrapper #(
	parameter WIDTH = 1
	)(
	input wire clk,
	input wire [WIDTH-1:0]dout,
	input wire pin_capture,
	output wire pin_out
);

(* keep="true" *) reg [WIDTH-1:0]capture;

always @(posedge clk)
	if (pin_capture)
		capture <= dout;

assign pin_out = ^capture;

endmodule
