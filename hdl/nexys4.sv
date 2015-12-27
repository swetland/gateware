// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

module top(
	input clk,
	output reg[15:0]led
	);

wire [15:0]wdata;
wire [15:0]waddr;
wire [15:0]raddr;
wire [15:0]rdata;
wire wr;
wire rd;

assign led = raddr;

sram ram0(
        .clk(clk),
        .waddr(waddr),
        .wdata(wdata),
        .we(wr),
        .raddr(raddr),
        .rdata(rdata),
        .re(rd)
	);

cpu 
`ifdef BIGCPU
        #(
        .RWIDTH(32),
        .SWIDTH(5)
        )
`endif
        cpu0(
        .clk(clk),
        .mem_raddr_o(raddr),
        .mem_rdata_i(rdata),
        .mem_waddr_o(waddr),
        .mem_wdata_o(wdata),
        .mem_wr_o(wr),
        .mem_rd_o(rd)
        );

endmodule

module sram(
	input clk,
	input [15:0]waddr,
	input [15:0]wdata,
	input [15:0]raddr,
	output reg [15:0]rdata,
	input we,
	input re
	);

reg [15:0]mem[0:4095];

always @(posedge clk) begin
	if (we)
		mem[waddr[11:0]] <= wdata;
	if (re)
		rdata <= mem[raddr[11:0]];
end

endmodule
