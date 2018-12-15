// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

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

wire hdmi_clk_src;

`ifdef verilator
assign hdmi_clk = hdmi_clk_src;
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
	.OUTPUT_CLK(hdmi_clk_src),
	.D_OUT_0(1'b1),
	.D_OUT_1(1'b0),
	.D_IN_0(),
	.D_IN_1()
	);
`endif

system_cpu16_vga40x30 #(
	.BPP(1)
	) system (
	.clk12m_in(clk12m_in),
	.vga_red(hdmi_red),
	.vga_grn(hdmi_grn),
	.vga_blu(hdmi_blu),
	.vga_hsync(hdmi_hsync),
	.vga_vsync(hdmi_vsync),
	.vga_active(hdmi_de),
	.vga_clk(hdmi_clk_src),
	.spi_mosi(),
	.spi_miso(),
	.spi_clk(),
	.spi_cs(),
	.uart_rx(uart_rx),
	.uart_tx(uart_tx),
	.led_red(led_red),
	.led_grn(led_grn),
	.out1(),
	.out2()
	);

endmodule
