// Copyright 2014, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module dvi_backend (
	input pixclk,
	input pixclk5x,

	// TMDS33 outputs at pixclk5x DDR
	output wire [3:0]pin_dvi_dp,
	output wire [3:0]pin_dvi_dn,

	// RGB data input at pixclk
	input wire hsync,
	input wire vsync,
	input wire active,
	input wire [7:0]red,
	input wire [7:0]grn,
	input wire [7:0]blu
	);

wire [3:0]dvi_dp;
wire [3:0]dvi_dn;

wire [9:0] ch0, ch1, ch2;

reg [9:0]ch3 = 10'b0000011111;

dvi_encoder enc2(
	.clk(pixclk),
	.din(red),
	.ctrl(0),
	.active(active),
	.dout(ch2));

dvi_encoder enc1(
	.clk(pixclk),
	.active(active),
	.din(grn),
	.ctrl(0),
	.dout(ch1));

dvi_encoder enc0(
	.clk(pixclk),
	.active(active),
	.din(blu),
	.ctrl({vsync,hsync}),
	.dout(ch0));

// shift registers
reg [9:0]ch0s;
reg [9:0]ch1s;
reg [9:0]ch2s;
reg [9:0]ch3s;

reg [4:0]cycle = 5'b00001;

// TODO ideally cycle[0] would occur on the 4th
// pixclk5x tick within every pixclk
//
always_ff @(posedge pixclk5x) begin
	cycle <= { cycle[0], cycle[4:1] };
	ch0s <= cycle[0] ? ch0 : { 2'b0, ch0s[9:2] };
	ch1s <= cycle[0] ? ch1 : { 2'b0, ch1s[9:2] };
	ch2s <= cycle[0] ? ch2 : { 2'b0, ch2s[9:2] };
	ch3s <= cycle[0] ? ch3 : { 2'b0, ch3s[9:2] };
end

dvi_ddr_out ddo0 (
	.clk(pixclk5x),
	.din(ch0s[1:0]),
	.pin_dp(pin_dvi_dp[0]),
	.pin_dn(pin_dvi_dn[0]));

dvi_ddr_out ddo1 (
	.clk(pixclk5x),
	.din(ch1s[1:0]),
	.pin_dp(pin_dvi_dp[1]),
	.pin_dn(pin_dvi_dn[1]));

dvi_ddr_out ddo2 (
	.clk(pixclk5x),
	.din(ch2s[1:0]),
	.pin_dp(pin_dvi_dp[2]),
	.pin_dn(pin_dvi_dn[2]));

dvi_ddr_out ddo3 (
	.clk(pixclk5x),
	.din(ch3s[1:0]),
	.pin_dp(pin_dvi_dp[3]),
	.pin_dn(pin_dvi_dn[3]));

endmodule

module dvi_ddr_out(
	input wire clk,
	input wire [1:0]din,
	output wire pin_dp,
	output wire pin_dn
);

`ifndef verilator
ODDRX1F dp(
	.D0(din[0]),
	.D1(din[1]),
	.Q(pin_dp),
	.SCLK(clk),
	.RST(0));

ODDRX1F dn(
	.D0(~din[0]),
	.D1(~din[1]),
	.Q(pin_dn),
	.SCLK(clk),
	.RST(0));
`endif

endmodule

