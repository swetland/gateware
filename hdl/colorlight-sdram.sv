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

`define CLK125
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

wire testclk = clk125m;

wire [19:0]rd_addr;
wire [15:0]rd_data;
wire [3:0]rd_len;
wire rd_req;
wire rd_ack;
wire rd_rdy;

wire [19:0]wr_addr;
wire [15:0]wr_data;
wire wr_req;
wire wr_ack;
wire [3:0]wr_len;

wire [15:0]info;
wire info_e;

testbench #(
	.BANKBITS(1),
	.ROWBITS(11),
	.COLBITS(8)
	) test0 (
	.clk(testclk),
	.error(),
	.done(),

	.rd_addr(rd_addr),
	.rd_data(rd_data),
	.rd_len(rd_len),
	.rd_req(rd_req),
	.rd_ack(rd_ack),
	.rd_rdy(rd_rdy),

	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.wr_len(wr_len),
	.wr_req(wr_req),
	.wr_ack(wr_ack),

	.info(info),
	.info_e(info_e)
);

sdram #(
	.BANKBITS(1),
	.ROWBITS(11),
	.COLBITS(8),
	.T_PWR_UP(25000),
	.T_RI(1900),
	.T_RCD(3), 
	.CLK_SHIFT(1),
	.CLK_DELAY(0)
	) sdram0 (
	.clk(testclk),
	.reset(0),

	.pin_clk(sdram_clk),
	.pin_ras_n(sdram_ras_n),
	.pin_cas_n(sdram_cas_n),
	.pin_we_n(sdram_we_n),
	.pin_addr(sdram_addr),
	.pin_data(sdram_data),

`ifdef SWIZZLE
	.rd_addr({rd_addr[7:4],rd_addr[19:8],rd_addr[3:0]}),
	.wr_addr({wr_addr[7:4],wr_addr[19:8],wr_addr[3:0]}),
`else
	.rd_addr(rd_addr),
	.wr_addr(wr_addr),
`endif

	.rd_data(rd_data),
	.rd_len(rd_len),
	.rd_req(rd_req),
	.rd_ack(rd_ack),
	.rd_rdy(rd_rdy),

	.wr_data(wr_data),
	.wr_len(wr_len),
	.wr_req(wr_req),
	.wr_ack(wr_ack)
);


assign j1r1 = j1r0;
assign j1b1 = j1b0;
assign j1g1 = j1g0;

reg [10:0]waddr = 11'd0;

wire [10:0]waddr_next = (waddr == 11'd1199) ? 11'd0 : (waddr + 11'd1);

always_ff @(posedge testclk) begin
	waddr <= (info_e) ? waddr_next : waddr;
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
        .waddr({waddr,1'b0}),
        .wdata(info),
        .we(info_e)
);

endmodule

