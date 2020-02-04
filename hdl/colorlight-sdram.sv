// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module top(
	input wire phy_clk,

	output sdram_clk,
	output sdram_ras_n,
	output sdram_cas_n,
	output sdram_we_n,
	output [11:0]sdram_addr,
	inout [15:0]sdram_data,

	output wire glb_clk,
	output wire glb_bln,
	output wire j1r0,
	output wire j1r1,
	output wire j1g0,
	output wire j1g1,
	output wire j1b0,
	output wire j1b1,
	output wire glb_a,
	output wire glb_b,
	input wire btn
);

wire clk25m = phy_clk;

`ifdef CLK125
wire clk125m;
wire clk250m;

pll_25_125_250 pll(
	.clk25m_in(phy_clk),
	.clk125m_out(clk125m),
	.clk250m_out(clk250m),
	.locked()
);
`else
wire clk100m;

pll_25_100 pll(
	.clk25m_in(phy_clk),
	.clk100m_out(clk100m),
	.locked()
);
`endif

wire testclk = clk100m;

wire [15:0]info;
wire info_e;

testbench #(
	.T_PWR_UP(25000), 
	.T_RI(1900)
	) test0 (
	.clk(testclk),
	.error(),
	.done(),
	.sdram_clk(sdram_clk),
	.sdram_ras_n(sdram_ras_n),
	.sdram_cas_n(sdram_cas_n),
	.sdram_we_n(sdram_we_n),
	.sdram_addr(sdram_addr),
`ifdef verilator
	.sdram_data_i(sdram_data),
	.sdram_data_o(),
`else
	.sdram_data(sdram_data),
`endif
	.info(info),
	.info_e(info_e)
);


assign j1r1 = j1r0;
assign j1b1 = j1b0;
assign j1g1 = j1g0;

reg [11:0]waddr = 12'd0;

always_ff @(posedge testclk) begin
	waddr <= (info_e)  ? (waddr + 12'd2) : waddr;
end

display #(
        .BPP(1),
        .RGB(1),
        .WIDE(0),
	.HEXMODE(1)
        ) display0 (
        .clk(clk25m),
        .red(j1r0),
        .grn(j1g0),
        .blu(j1b0),
        .hsync(glb_a),
        .vsync(glb_b),
        .active(),
        .frame(),
        .wclk(testclk),
        .waddr(waddr),
        .wdata(info),
        .we(info_e)
);

endmodule

