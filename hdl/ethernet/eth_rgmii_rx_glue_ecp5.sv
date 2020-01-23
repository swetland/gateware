// Copyright 2020 Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module eth_rgmii_rx_glue (
	input wire rx_clk,
	input wire pin_rx_dv,
	input wire [3:0]pin_rx_data,
	output wire rx_dv,
	output wire rx_err,
	output wire [7:0]rx_data
);

`ifndef verilator
wire delay_rx_dv;
wire [3:0]delay_rx_data;

DELAYF #(
	.DEL_MODE("SCLK_CENTERED"),
	.DEL_VALUE(80) // units of ~25ps
	) ctrl_delay (
	.LOADN(1),
	.MOVE(0),
	.DIRECTION(0),
	.A(pin_rx_dv),
	.Z(delay_rx_dv)
);
IDDRX1F ctrl_ddr (
	.D(delay_rx_dv),
	.SCLK(rx_clk),
	.RST(0),
	.Q0(rx_dv),
	.Q1(rx_err)
);

genvar i;

generate for (i = 0; i < 4; i++) begin
DELAYF #(
	.DEL_MODE("SCLK_CENTERED"),
	.DEL_VALUE(80) // units of ~25ps
	) data_delay (
	.LOADN(1),
	.MOVE(0),
	.DIRECTION(0),
	.A(pin_rx_data[i]),
	.Z(delay_rx_data[i])
);
IDDRX1F data_ddr (
	.D(delay_rx_data[i]),
	.SCLK(rx_clk),
	.RST(0),
	.Q0(rx_data[i]),
	.Q1(rx_data[i+4])
);
end endgenerate
`endif

endmodule
