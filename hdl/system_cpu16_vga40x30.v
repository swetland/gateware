// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

`define WITH_CPU

module system_cpu16_vga40x30 #(
	parameter BPP = 2
)(
	input clk12m_in,
	output [BPP-1:0]vga_red,
	output [BPP-1:0]vga_grn,
	output [BPP-1:0]vga_blu,
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

assign out1 = clk12m;
assign out2 = clk25m;

pll_12_25 pll0(
	.clk12m_in(clk12m_in),
	.clk12m_out(clk12m),
	.clk25m_out(clk25m),
	.lock(),
	.reset(1'b1)
	);

wire sys_clk;

`ifdef USE_HFOSC
SB_HFOSC #(
	.CLKHF_DIV("0b00")
	)hfosc(
	.CLKHFEN(1'b1),
	.CLKHFPU(1'b1),
	.CLKHF(sys_clk)
	);
`else
assign sys_clk = clk12m;
`endif

reg cpu_reset = 1'b0;

// cpu memory interface
wire [15:0]ins_rd_addr;
wire [15:0]ins_rd_data;
wire ins_rd_req;

wire [15:0]dat_rw_addr;
wire [15:0]dat_rd_data;
wire dat_rd_req;
wire [15:0]dat_wr_data;
wire dat_wr_req;

`ifndef WITH_CPU
assign ins_rd_req = 1'b0;
assign dat_rd_req = 1'b0;
assign dat_wr_req = 1'b0;
assign ins_rd_addr = 16'd0;
assign dat_rw_addr = 16'd0;
`else
// fake arbitration that never denies a request
reg ins_rd_rdy = 1'b0;
reg dat_rd_rdy = 1'b0;
reg dat_wr_rdy = 1'b0;

always_ff @(posedge sys_clk) begin
	if (cpu_reset) begin
		ins_rd_rdy <= 1'b0;
		dat_rd_rdy <= 1'b0;
		dat_wr_rdy <= 1'b0;
	end else begin
		ins_rd_rdy <= ins_rd_req;
		dat_rd_rdy <= dat_rd_req;
		dat_wr_rdy <= dat_wr_req;
	end
end

// until arbitration works
assign dat_rd_data = 16'hEEEE;

cpu16 cpu(
	.clk(sys_clk),
	.ins_rd_addr(ins_rd_addr),
	.ins_rd_data(ins_rd_data),
	.ins_rd_req(ins_rd_req),
	.ins_rd_rdy(ins_rd_rdy),

	.dat_rw_addr(dat_rw_addr),
	.dat_wr_data(dat_wr_data),
	.dat_rd_data(dat_rd_data),
	.dat_rd_req(dat_rd_req),
	.dat_rd_rdy(dat_rd_rdy),
	.dat_wr_req(dat_wr_req),
	.dat_wr_rdy(dat_wr_rdy),

	.reset(cpu_reset)
	) /* synthesis syn_keep=1 */;
`endif

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
wire we = dbg_we | dat_wr_req;
wire [15:0]waddr = dbg_we ? dbg_waddr : dat_rw_addr;
wire [15:0]wdata = dbg_we ? dbg_wdata : dat_wr_data;

wire w_cs_sram = (waddr[15:12] == 4'h0);
wire w_cs_vram = (waddr[15:12] == 4'h8);
wire w_cs_ctrl = (waddr[15:12] == 4'hF);

always @(posedge sys_clk) begin
	if (w_cs_ctrl & we) begin
		cpu_reset <= wdata[0];
	end
end

sram ram0(
	.clk(sys_clk),
	.raddr(ins_rd_addr),
	.rdata(ins_rd_data),
	.re(ins_rd_req),
	.waddr(waddr),
	.wdata(wdata),
	.we(we & w_cs_sram)
	);

wire [BPP-1:0]vr;
wire [BPP-1:0]vg;
wire [BPP-1:0]vb;

vga40x30x2 #(
	.BPP(BPP)
	) vga (
	.clk25m(clk25m),
	.red(vr),
	.grn(vg),
	.blu(vb),
	.hs(vga_hsync),
	.vs(vga_vsync),
	.fr(),
	.vram_waddr(waddr[10:0]),
	.vram_wdata(wdata[7:0]),
	.vram_we(we & w_cs_vram),
	.vram_clk(sys_clk)
	);

// hack: flip display from blue to red when CPU is held in reset
assign vga_red = cpu_reset ? vb : vr;
assign vga_grn = vg;
assign vga_blu = cpu_reset ? vr : vb;

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

`ifndef USE_LATTICE_SB_RAM40
reg [15:0]mem[255:0];
reg [15:0]ra;
always @(posedge clk) begin
	if (we)
		mem[waddr[7:0]] <= wdata;
	if (re)
		ra <= mem[raddr[7:0]];
end
assign rdata = ra;
`else

`ifdef YOSYS
SB_RAM40_4K #(
        .READ_MODE(0),
        .WRITE_MODE(0)
        )
`else
SB_RAM256x16
`endif
	sram_inst(
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
	.MASK(16'b0)
	);
`endif

endmodule
