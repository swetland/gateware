// Copyright 2012, Brian Swetland.  Use at your own risk.
//
// sync sram with independent read/write addressing

`timescale 1ns/1ns

module videoram #(parameter DWIDTH=16, parameter AWIDTH=8) (
	input clk, input we,
	input [AWIDTH-1:0] waddr,
	input [DWIDTH-1:0] wdata,
	input [AWIDTH-1:0] raddr,
	output reg [DWIDTH-1:0] rdata
	);

reg [DWIDTH-1:0] mem[0:2**AWIDTH-1];

initial $readmemh("vram.txt", mem);

always @(posedge clk) begin
	if (we)
		mem[waddr] <= wdata;
	rdata <= mem[raddr];
end

endmodule
