// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module testbench #(
	parameter T_PWR_UP = 3,
	parameter T_RI = 32
	) (
	input clk,
	output reg error = 0,
	output reg done = 0,
	
	output wire sdram_clk,
	output wire sdram_ras_n,
	output wire sdram_cas_n,
	output wire sdram_we_n,
	output wire [11:0]sdram_addr,
`ifdef verilator
	input wire [15:0]sdram_data_i,
	output wire [15:0]sdram_data_o,
`else
	inout wire [15:0]sdram_data,
`endif
	output reg [15:0]info = 0,
	output reg info_e = 0
);

reg [15:0]info_next;
reg info_e_next;

reg [19:0]rd_addr = 0;
wire [15:0]rd_data;
reg rd_ready = 0;
wire rd_valid;

reg [19:0]wr_addr = 0;
reg [15:0]wr_data = 0;
reg wr_valid = 0;
wire wr_ready;

reg [31:0]count = T_PWR_UP + 32;
reg [31:0]count_next;
wire [31:0]count_sub1;
wire count_done;

assign { count_done, count_sub1 } = { 1'b0, count } - 32'd1;

localparam INIT = 4'd0;
localparam WRITES = 4'd1;
localparam READS = 4'd2;
localparam STOP = 4'd3;

reg [3:0]state = INIT;
reg [3:0]state_next;

reg rd_ready_next;
reg wr_valid_next;
reg [19:0]wr_addr_next;
reg [19:0]rd_addr_next;
reg [15:0]wr_data_next;
reg done_next;

always_comb begin
	state_next = state;
	count_next = count;
	rd_ready_next = rd_ready;
	wr_valid_next = wr_valid;
	wr_addr_next = wr_addr;
	rd_addr_next = rd_addr;
	wr_data_next = wr_data;
	info_next = info;
	info_e_next = 0;
	done_next = 0;

	case (state)
	INIT: if (count_done) begin
		state_next = WRITES;
		count_next = 32;
		wr_addr_next = 0;
		wr_data_next = 0;
		wr_valid_next = 1;
		info_next = 16'h10FF;
		info_e_next = 1;
	end else begin
		count_next = count_sub1;
	end
	WRITES: if (count_done) begin
		state_next = READS;
		count_next = 32;
		rd_addr_next = 0;
		rd_ready_next = 1;
		wr_valid_next = 0;
		info_next = 16'h20EE;
		info_e_next = 1;
	end else begin
		if (wr_ready) begin
			wr_data_next = wr_data + 1;
			wr_addr_next = wr_addr + 1;
			count_next = count_sub1;
		end
	end
	READS: if (count_done) begin
		state_next = STOP;
		done_next = 1;
		rd_ready_next = 0;
		info_next = 16'h20DD;
		info_e_next = 1;
	end else begin
		if (rd_valid) begin
			rd_addr_next = rd_addr + 1;
			count_next = count_sub1;
			info_next = { 8'h40, rd_data[7:0] };
			info_e_next = 1;
		end
	end
	STOP: state_next = STOP;
	default: state_next = INIT;
	endcase
end

always_ff @(posedge clk) begin
	state <= state_next;
	rd_ready <= rd_ready_next;
	wr_valid <= wr_valid_next;
	rd_addr <= rd_addr_next;
	wr_addr <= wr_addr_next;
	wr_data <= wr_data_next;
	count <= count_next;
	done <= done_next;
	info <= info_next;
	info_e <= info_e_next;
end

sdram #(
	.T_PWR_UP(T_PWR_UP),
	.T_RI(T_RI)
	) sdram0 (
	.clk(clk),

	.pin_clk(sdram_clk),
	.pin_ras_n(sdram_ras_n),
	.pin_cas_n(sdram_cas_n),
	.pin_we_n(sdram_we_n),
	.pin_addr(sdram_addr),
`ifdef verilator
	.pin_data_i(sdram_data_i),
	.pin_data_o(sdram_data_o),
`else
	.pin_data(sdram_data),
`endif
	.rd_addr(rd_addr),
	.rd_data(rd_data),
	.rd_ready(rd_ready),
	.rd_valid(rd_valid),

	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.wr_valid(wr_valid),
	.wr_ready(wr_ready)
);

endmodule
