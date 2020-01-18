// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module top(
	input clk12m_in,
	output hdmi_red,
	output hdmi_grn,
	output hdmi_blu,
	output hdmi_hsync,
	output hdmi_vsync,
	output hdmi_de,
	output hdmi_clk,
	input uart_rx,
	output uart_tx,
	output led_red,
	output led_grn
);

wire clk12m;
wire clk25m;

pll_12_25 pll0 (
	.clk12m_in(clk12m_in),
	.clk12m_out(clk12m),
	.clk25m_out(clk25m),
	.lock(),
	.reset(1'b1)
);

`ifdef verilator
assign hdmi_clk = clk25m;
`else
SB_IO #(
	.PIN_TYPE(6'b010000), // DDR OUTPUT
	.PULLUP(1'b0),
	.NEG_TRIGGER(1'b0),
	.IO_STANDARD("SB_LVCMOS")
	) hdmi_clk_io (
	.PACKAGE_PIN(hdmi_clk),
	.LATCH_INPUT_VALUE(),
	.CLOCK_ENABLE(), // per docs, leave discon for always enable
	.INPUT_CLK(),
	.OUTPUT_CLK(clk25m),
	.D_OUT_0(1'b1),
	.D_OUT_1(1'b0),
	.D_IN_0(),
	.D_IN_1()
	);
`endif

wire [15:0]dbg_wdata;
wire [15:0]dbg_waddr;
wire dbg_we;

display #(
	.BPP(1),
	) display0 (
	.clk(clk25m),
	.red(hdmi_red),
	.grn(hdmi_grn),
	.blu(hdmi_blu),
	.hsync(hdmi_hsync),
	.vsync(hdmi_vsync),
	.active(hdmi_de),
	.frame(),
	.wclk(clk25m),
	.waddr(dbg_waddr[11:0]),
	.wdata(dbg_wdata[15:0]),
	.we(dbg_we)
);

uart_debug_ifc uart(
	.sys_clk(clk12m),
	.sys_wr(dbg_we),
	.sys_waddr(dbg_waddr),
	.sys_wdata(dbg_wdata),
	.uart_rx(uart_rx),
	.uart_tx(uart_tx),
	.led_red(led_red),
	.led_grn(led_grn)
	);

endmodule
