// Copyright 2012, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.
//
// sync sram with independent read/write addressing

`timescale 1ns/1ns

module videoram #(parameter DWIDTH=16, parameter AWIDTH=8) (
	input wclk, input we,
	input [AWIDTH-1:0] waddr,
	input [DWIDTH-1:0] wdata,
	input rclk, input re,
	input [AWIDTH-1:0] raddr,
	output [DWIDTH-1:0] rdata
	);

reg [DWIDTH-1:0] mem[0:2**AWIDTH-1];
reg [DWIDTH-1:0] data;

assign rdata = data;

`ifdef HEX_PATHS
initial $readmemh("hdl/vga/vram.txt", mem);
`else
initial $readmemh("vram.txt", mem);
`endif

always @(posedge wclk) begin
	if (we)
		mem[waddr] <= wdata;
end

always @(posedge rclk) begin
	if (re)
		data <= mem[raddr];
end

endmodule
