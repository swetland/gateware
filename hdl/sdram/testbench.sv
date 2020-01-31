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
reg rd_req = 0;
reg [3:0]rd_len = 0;
wire rd_ack;
wire rd_rdy;

reg [19:0]wr_addr = 0;
reg [15:0]wr_data = 0;
reg wr_req = 0;
wire wr_ack;

reg rd_req_next;
reg wr_req_next;
reg [3:0]rd_len_next;
reg [19:0]wr_addr_next;
reg [19:0]rd_addr_next;
reg [15:0]wr_data_next;

reg done_next;
reg error_next;

reg [15:0]count = T_PWR_UP + 32;
reg [15:0]count_next;
wire [15:0]count_sub1;
wire count_done;

assign { count_done, count_sub1 } = { 1'b0, count } - 16'd1;

localparam INIT = 4'd0;
localparam WRITES = 4'd1;
localparam READS = 4'd2;
localparam STOP = 4'd3;

reg [3:0]state = INIT;
reg [3:0]state_next;

reg number_next;
reg number_reset;
wire [31:0]number;

xorshift32 xs(
	.clk(clk),
	.next(number_next),
	.reset(number_reset),
	.data(number)
);

reg [15:0]cycles = 0;
reg [15:0]cycles_next;

reg reset = 1;

always_comb begin
	number_reset = 0;
	number_next = 0;
	state_next = state;
	count_next = count;
	rd_req_next = rd_req;
	wr_req_next = wr_req;
	wr_addr_next = wr_addr;
	rd_addr_next = rd_addr;
	rd_len_next = rd_len;
	wr_data_next = wr_data;
	info_next = info;
	info_e_next = 0;
	done_next = 0;
	error_next = 0;
	cycles_next = cycles + 16'd1;

	if (cycles == 16'd5000)
		error_next = 1;

	case (state)
	INIT: if (count_done) begin
		state_next = WRITES;
		count_next = 1000; //32;
		wr_addr_next = 20'hF0;
		//wr_data_next = 0;
		wr_data_next= number[15:0];
		number_next = 1;
		wr_req_next = 1;
		info_next = 16'h10FF;
		info_e_next = 1;
	end else begin
		count_next = count_sub1;
	end
	WRITES: if (count_done) begin
		state_next = READS;
		number_reset = 1;
		count_next = 1000; //32;
		rd_addr_next = 20'hF0;
		rd_req_next = 1;
		wr_req_next = 0;
		info_next = 16'h20EE;
		info_e_next = 1;
	end else begin
		if (wr_ack) begin
			//wr_data_next = wr_data + 1;
			wr_data_next = number[15:0];
			number_next = 1;
			wr_addr_next = wr_addr + 1;
			count_next = count_sub1;
		end
	end
	READS: if (count_done) begin
		state_next = STOP;
		done_next = 1;
		info_next = 16'h20DD;
		info_e_next = 1;
		rd_req_next = 0;
	end else begin
		if (rd_ack) begin
			rd_req_next = 0;
		end
		if (rd_rdy) begin
			rd_req_next = 1;
			rd_addr_next = rd_addr + 1;
			count_next = count_sub1;
			if (rd_data == number[15:0])
				info_next = { 16'h7011 };
			else
				info_next = { 16'h40FF };
			//info_next = { 8'h40, rd_data[7:0] };
			number_next = 1;
			info_e_next = 1;
		end
	end
	STOP: state_next = STOP;
	default: state_next = INIT;
	endcase
end

always_ff @(posedge clk) begin
	state <= state_next;
	rd_req <= rd_req_next;
	wr_req <= wr_req_next;
	rd_addr <= rd_addr_next;
	wr_addr <= wr_addr_next;
	wr_data <= wr_data_next;
	rd_len <= rd_len_next;
	count <= count_next;
	info <= info_next;
	info_e <= info_e_next;

	cycles <= cycles_next;
	done <= done_next;
	error <= error_next;
	reset <= 0;
end

sdram #(
	.T_PWR_UP(T_PWR_UP),
	.T_RI(T_RI)
	) sdram0 (
	.clk(clk),
	.reset(reset),

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
	.rd_len(rd_len),
	.rd_req(rd_req),
	.rd_ack(rd_ack),
	.rd_data(rd_data),
	.rd_rdy(rd_rdy),

	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.wr_len(0),
	.wr_req(wr_req),
	.wr_ack(wr_ack)
);

endmodule
