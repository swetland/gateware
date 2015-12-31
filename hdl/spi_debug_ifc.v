// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module spi_debug_ifc(
	input spi_clk,
	input spi_cs_i,
	input spi_data_i,
	output spi_data_o,
	input sys_clk,
	output sys_wr_o,
	output [15:0]sys_waddr_o,
	output [15:0]sys_wdata_o
	);

reg [15:0]spi_shift = 16'd0;
reg [16:0]spi_data = 17'd0;
reg [3:0]spi_count = 4'd0;
reg spi_signal = 1'd0;
reg spi_flag = 1'd0;

assign spi_data_o = 1'b0;

wire [15:0]spi_next = { spi_data_i, spi_shift[15:1] };

reg [15:0]spi_shift_next;
reg [16:0]spi_data_next;
reg [3:0]spi_count_next;
reg spi_signal_next;
reg spi_flag_next;

always @(*) begin
	spi_shift_next = spi_shift;
	spi_data_next = spi_data;
	spi_count_next = spi_count;
	spi_signal_next = spi_signal;
	spi_flag_next = spi_flag;

	if (spi_cs_i) begin
		spi_count_next = 4'd0;
		spi_flag_next = 1'b1;
	end else begin
		spi_shift_next = spi_next;
		spi_count_next = spi_count + 4'd1;
		if (spi_count == 4'd15) begin
			spi_data_next = { spi_flag, spi_next };
			spi_signal_next = ~spi_signal;
			spi_flag_next = 1'b0;
		end
	end
end

always @(posedge spi_clk) begin
	spi_shift <= spi_shift_next;
	spi_data <= spi_data_next;
	spi_count <= spi_count_next;
	spi_signal <= spi_signal_next;
	spi_flag <= spi_flag_next;
end

wire sys_signal;

sync_oneway sync_spi_sys(
	.txclk(spi_clk),
	.txdat(spi_signal),
	.rxclk(sys_clk),
	.rxdat(sys_signal)
	);

reg sys_signal_ack = 1'b0;
reg enabled = 1'b0;
reg [15:0]addr;
reg [15:0]data;
reg wr = 1'b0;

reg [15:0]addr_next;
reg [15:0]data_next;
reg enabled_next;
reg sys_signal_ack_next;
reg wr_next;

reg [15:0]delay = 16'd0;
reg [15:0]delay_next;

always @(*) begin
	delay_next = delay;
	addr_next = addr;
	data_next = data;
	sys_signal_ack_next = sys_signal_ack;
	wr_next = wr;

	// ensure we're up and running before accepting writes
	// there's got to be a nicer way to do this
	if (delay != 16'hFFFF) begin
		delay_next = delay + 1'd1;
		enabled_next = 1'b0;
	end else begin
		enabled_next = 1'b1;
	end

	if (sys_signal ^ sys_signal_ack) begin
		sys_signal_ack_next = ~sys_signal_ack;
		if (spi_data[16]) begin
			addr_next = spi_data[15:0];
		end else begin
			data_next = spi_data[15:0];
			wr_next = 1'b1;
		end
	end else begin
		if (wr) begin
			wr_next = 1'b0;
			addr_next = addr + 16'd1;
		end
	end
end

always @(posedge sys_clk) begin
	delay <= delay_next;
	addr <= addr_next;
	data <= data_next;
	enabled <= enabled_next;
	sys_signal_ack <= sys_signal_ack_next;
	wr <= wr_next;
end

assign sys_wr_o = wr & enabled;
assign sys_waddr_o = addr;
assign sys_wdata_o = data;

endmodule



module sync_oneway(
	input txclk,
	input txdat,
	input rxclk,
	output rxdat
	);

reg a = 0;

// these should be adjacent
reg b = 0, c = 0;

always @(posedge txclk)
	a <= txdat;

always @(posedge rxclk) begin
	b <= a;
	c <= b;
end

assign rxdat = c;

endmodule
