// Copyright 2020 Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module eth_rgmii_tx_glue (
	input wire tx_clk,
	output wire pin_tx_clk,
	output wire pin_tx_en,
	output wire [3:0]pin_tx_data,
	input wire tx_en,
	input wire tx_err,
	input wire [7:0]tx_data
);

`ifndef verilator
wire delay_tx_clk;
wire delay_tx_en;
wire delay_tx_err;
wire [3:0]delay_tx_data;

DELAYF #(
	.DEL_MODE("SCLK_CENTERED"),
	.DEL_VALUE(0) // units of ~25ps
	) clock_delay (
	.LOADN(1),
	.MOVE(0),
	.DIRECTION(0),
	.A(delay_tx_clk),
	.Z(pin_tx_clk)
);
ODDRX1F clock_ddr (
	//.Q(delay_tx_clk),
	.Q(delay_tx_clk),
	.SCLK(tx_clk),
	.RST(0),
	.D0(1),
	.D1(0)
);

DELAYF #(
	.DEL_MODE("SCLK_CENTERED"),
	.DEL_VALUE(0) // units of ~25ps
	) ctrl_delay (
	.LOADN(1),
	.MOVE(0),
	.DIRECTION(0),
	.A(delay_tx_en),
	.Z(pin_tx_en)
);
ODDRX1F ctrl_ddr (
	.Q(delay_tx_en),
	.SCLK(tx_clk),
	.RST(0),
	.D0(tx_en),
	.D1(tx_err ^ tx_en)
);

genvar i;

generate for (i = 0; i < 4; i++) begin
DELAYF #(
	.DEL_MODE("SCLK_CENTERED"),
	.DEL_VALUE(0) // units of ~25ps
	) data_delay (
	.LOADN(1),
	.MOVE(0),
	.DIRECTION(0),
	.A(delay_tx_data[i]),
	.Z(pin_tx_data[i])
);
ODDRX1F data_ddr (
	.Q(delay_tx_data[i]),
	.SCLK(tx_clk),
	.RST(0),
	.D0(tx_data[i]),
	.D1(tx_data[i+4])
);
end endgenerate
`endif

endmodule
