// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module testbench(
	input clk
	);

reg [15:0]count = 16'd0;
reg reset = 1'b0;

reg burp = 1'b0;

always @(posedge clk) begin
	count <= count + 16'd1;
	burp <= (count >= 16'd0010) && (count <= 16'd0012) ? 1'b1 : 1'b0;
	if (count == 16'd0005) reset <= 1'b0;
	if (count == 16'd1000) $finish;
	if (cpu.ir == 16'hFFFF) begin
		for ( integer i = 0; i < 8; i++ ) begin
			$display(":REG R%0d %8X", i, cpu.regs.rmem[i]);
		end
		$display(":END");
		$finish;
	end
end

wire [15:0]ins_rd_addr;
wire [15:0]ins_rd_data;
wire ins_rd_req;

wire [15:0]dat_rw_addr;
wire [15:0]dat_rd_data;
wire dat_rd_req;
wire [15:0]dat_wr_data;
wire dat_wr_req;

reg ins_rd_rdy = 1'b0;
reg dat_rd_rdy = 1'b0;
reg dat_wr_rdy = 1'b0;

always_ff @(posedge clk) begin
	if (reset) begin
		ins_rd_rdy <= 1'b0;
		dat_rd_rdy <= 1'b0;
		dat_wr_rdy <= 1'b0;
	end else begin
		ins_rd_rdy <= ins_rd_req;
		dat_rd_rdy <= dat_rd_req;
		dat_wr_rdy <= dat_wr_req;
	end
end

simram ins_ram(
	.clk(clk),
	.waddr(16'd0),
	.wdata(16'd0),
	.we(1'd0),
	.raddr(ins_rd_addr),
	.rdata(ins_rd_data),
	.re(1'd1)
	);

simram dat_ram(
	.clk(clk),
	.waddr(dat_rw_addr),
	.wdata(dat_wr_data),
	.we(dat_wr_req),
	.raddr(dat_rw_addr),
	.rdata(dat_rd_data),
	.re(dat_rd_req)
	);

cpu16 cpu(
	.clk(clk),
	.ins_rd_addr(ins_rd_addr),
	.ins_rd_data(burp ? 16'hEEEE : ins_rd_data),
	.ins_rd_req(ins_rd_req),
	.ins_rd_rdy(ins_rd_rdy & ~burp),

	.dat_rw_addr(dat_rw_addr),
	.dat_wr_data(dat_wr_data),
	.dat_rd_data(dat_rd_data),
	.dat_rd_req(dat_rd_req),
	.dat_rd_rdy(dat_rd_rdy),
	.dat_wr_req(dat_wr_req),
	.dat_wr_rdy(dat_wr_rdy),

	.reset(reset)
	);

endmodule
