// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

`define HAS_SDRAM

module top(
	input wire clk_25mhz,

`ifdef HAS_SDRAM
	output wire [7:0]led,

	output sdram_clk,
	output sdram_ras_n,
	output sdram_cas_n,
	output sdram_we_n,
	output [14:0]sdram_addr,
	inout [15:0]sdram_data,

	output sdram_cke,
	output sdram_cs_n,
	output [1:0]sdram_dqm,
`endif

	output [3:0]gpdi_dn,
	output [3:0]gpdi_dp // C R G B
);

`ifdef HAS_SDRAM
assign sdram_cke = 1;
assign sdram_cs_n = 0;
assign sdram_dqm = 2'b00;
`endif

wire clk25m = clk_25mhz;

`ifdef SLOWCLOCK
wire clk100m;
pll_25_100 pll(
	.clk25m_in(clk25m),
	.clk100m_out(clk100m),
	.locked()
);
wire testclk = clk100m;
`else
wire clk125m;
wire clk250m;
pll_25_125_250 pll(
	.clk25m_in(clk25m),
	.clk125m_out(clk125m),
	.clk250m_out(clk250m),
	.locked()
);
wire testclk = clk125m;
`endif

wire r,g,b;

wire [7:0]red = {8{r}};
wire [7:0]grn = {8{g}};
wire [7:0]blu = {8{b}};

wire active;
wire hsync;
wire vsync;

dvi_backend dvi0 (
	.pixclk(clk25m),
	.pixclk5x(clk125m),
	.pin_dvi_dp(gpdi_dp),
	.pin_dvi_dn(gpdi_dn),
	.hsync(hsync),
	.vsync(vsync),
	.active(active),
	.red(red),
	.grn(grn),
	.blu(blu)
);

wire [15:0]info;
wire info_e;

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
        .red(r),
        .grn(g),
        .blu(b),
        .hsync(hsync),
        .vsync(vsync),
        .active(active),
        .frame(),
        .wclk(testclk),
`ifdef HAS_SDRAM
        .waddr({waddr,1'b0}),
        .wdata(info),
        .we(info_e)
`else
        .waddr(0),
        .wdata(16'h0),
        .we(0)
`endif
);

`ifdef HAS_SDRAM
wire [24:0]rd_addr;
wire [15:0]rd_data;
wire [3:0]rd_len;
wire rd_req;
wire rd_ack;
wire rd_rdy;

wire [24:0]wr_addr;
wire [15:0]wr_data;
wire wr_req;
wire wr_ack;
wire [3:0]wr_len;

assign led = wr_addr[24:17];

testbench #(
	.BANKBITS(2),
	.ROWBITS(13),
	.COLBITS(10)
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
	.BANKBITS(2),
	.ROWBITS(13),
	.COLBITS(10),
	.T_PWR_UP(25000),
	.T_RI(750),
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
`endif

endmodule

