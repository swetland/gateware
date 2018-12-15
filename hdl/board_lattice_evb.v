// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

module top(
	input clk12m_in,
	output [1:0]vga_red,
	output [1:0]vga_grn,
	output [1:0]vga_blu,
	output vga_hsync,
	output vga_vsync,
	input spi_mosi,
	output spi_miso,
	input spi_clk,
	input spi_cs,
	output out1,
	output out2
	);

system_cpu16_vga40x30 #(
	.BPP(2)
	) system (
	.clk12m_in(clk12m_in),
	.vga_red(vga_red),
	.vga_grn(vga_grn),
	.vga_blu(vga_blu),
	.vga_hsync(vga_hsync),
	.vga_vsync(vga_vsync),
	.vga_active(),
	.vga_clk(),
	.spi_mosi(spi_mosi),
	.spi_miso(spi_miso),
	.spi_clk(spi_clk),
	.spi_cs(spi_cs),
	.uart_rx(1'b0),
	.uart_tx(),
	.led_grn(),
	.led_red(),
	.out1(out1),
	.out2(out2)
	);

endmodule
