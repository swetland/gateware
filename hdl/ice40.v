// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module top(
	input clk12m_in,
	output [1:0]vga_r,
	output [1:0]vga_g,
	output [1:0]vga_b,
	output vga_hsync,
	output vga_vsync,
	input spi_mosi,
	output spi_miso,
	input spi_clk,
	input spi_cs,
	output out1,
	output out2
	);

wire clk12m;
wire clk25m;

pll_12_25 pll0(
	.clk12m_in(clk12m_in),
	.clk12m_out(clk12m),
	.clk25m_out(clk25m),
	.lock(),
	.reset(1'b1)
	);

wire sys_clk = clk12m;

wire [15:0]cpu_waddr /* synthesis syn_keep=1 */;
wire [15:0]cpu_wdata /* synthesis syn_keep=1 */;
wire cpu_we /* synthesis syn_keep=1 */;
wire [15:0]cpu_raddr /* synthesis syn_keep=1 */;
wire [15:0]cpu_rdata /* synthesis syn_keep=1 */;
wire cpu_re /* synthesis syn_keep=1 */;

reg cpu_reset = 1'b0;

cpu #(
	.RWIDTH(16),
	.SWIDTH(4)
	)cpu0(
	.clk(sys_clk),
	.mem_waddr_o(cpu_waddr),
	.mem_wdata_o(cpu_wdata),
	.mem_wr_o(cpu_we),
	.mem_raddr_o(cpu_raddr),
	.mem_rdata_i(cpu_rdata),
	.mem_rd_o(cpu_re),
	.reset(cpu_reset)
	) /* synthesis syn_keep=1 */;

wire [15:0]dbg_waddr;
wire [15:0]dbg_wdata;
wire dbg_we;

spi_debug_ifc sdi(
	.spi_clk(spi_clk),
	.spi_cs_i(spi_cs),
	.spi_data_i(spi_mosi),
	.spi_data_o(spi_miso),
	.sys_clk(sys_clk),
	.sys_wr_o(dbg_we),
	.sys_waddr_o(dbg_waddr),
	.sys_wdata_o(dbg_wdata)
	);

// debug interface has priority over cpu writes
wire we = dbg_we | cpu_we;
wire [15:0]waddr = dbg_we ? dbg_waddr : cpu_waddr;
wire [15:0]wdata = dbg_we ? dbg_wdata : cpu_wdata;

wire cs_sram = (waddr[15:12] == 4'h0);
wire cs_vram = (waddr[15:12] == 4'h8);
wire cs_ctrl = (waddr[15:12] == 4'hF);

always @(posedge sys_clk) begin
	if (cs_ctrl & we) begin
		cpu_reset <= wdata[0];
	end
end

//assign out1 = cpu_reset;
//assign out2 = cpu_raddr[0];
assign out1 = cpu_we;
assign out2 = dbg_we;

wire cs0r = ~cpu_raddr[8];
wire cs1r = cpu_raddr[8];
wire cs0w = ~waddr[8];
wire cs1w = waddr[8];

wire [15:0]rdata0;
wire [15:0]rdata1;

assign cpu_rdata = cs0r ? rdata0 : rdata1;

sram ram0(
	.clk(sys_clk),
	.raddr(cpu_raddr),
	.rdata(rdata0),
	.re(cpu_re & cs0r & cs_sram),
	.waddr(waddr),
	.wdata(wdata),
	.we(we & cs0w & cs_sram)
	);

sram ram1(
	.clk(sys_clk),
	.raddr(cpu_raddr),
	.rdata(rdata1),
	.re(cpu_re & cs1r & cs_sram),
	.waddr(waddr),
	.wdata(wdata),
	.we(we & cs1w & cs_sram)
	);

vga40x30x2 vga(
	.clk25m(clk25m),
	.red(vga_r),
	.grn(vga_g),
	.blu(vga_b),
	.hs(vga_hsync),
	.vs(vga_vsync),
	.vram_waddr(waddr[10:0]),
	.vram_wdata(wdata[7:0]),
	.vram_we(we & cs_vram),
	.vram_clk(sys_clk)
	);

endmodule

module sram(
	input clk,
	input [15:0]raddr,
	output [15:0]rdata,
	input re,
	input [15:0]waddr,
	input [15:0]wdata,
	input we
	);

`ifndef uselatticeprim
reg [15:0]mem[255:0];
reg [15:0]ra;
always @(posedge clk) begin
	if (we)
		mem[waddr[7:0]] <= wdata;
	if (re)
		ra <= raddr;
end
assign rdata = mem[ra[7:0]];
`else
SB_RAM256x16 sram_inst(
	.RDATA(rdata),
	.RADDR(raddr[7:0]),
	.RCLK(clk),
	.RCLKE(1'b1),
	.RE(re),
	.WADDR(waddr[7:0]),
	.WDATA(wdata),
	.WCLK(clk),
	.WCLKE(1'b1),
	.WE(we),
	.MASK()
	);
`endif

endmodule
