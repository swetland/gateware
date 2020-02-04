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

reg [3:0]rd_len = 0;
reg rd_req = 0;
wire rd_ack;
wire [15:0]rd_data;
wire rd_rdy;

reg [3:0]wr_len = 0;
reg wr_req = 0;
wire wr_ack;

reg rd_req_next;
reg wr_req_next;
reg [3:0]rd_len_next;
reg [3:0]wr_len_next;

localparam AMSB = 19;
localparam DMSB = 15;

reg [AMSB:0]rd_addr = 0;
reg [AMSB:0]wr_addr = 0;
reg [DMSB:0]wr_data = 0;
reg [AMSB:0]rd_addr_next;
reg [AMSB:0]wr_addr_next;
reg [DMSB:0]wr_data_next;

// scratch memory to capture back-to-back and burst read results
reg [DMSB:0]scratch[0:1023];
reg [9:0]swraddr = 0;
reg [9:0]srdaddr = 0;
reg [DMSB:0]srddata = 0;
reg [9:0]swraddr_next;
reg [9:0]srdaddr_next;

reg sreset = 0;
reg srd = 0;

always_comb begin
	swraddr_next = swraddr;
	srdaddr_next = srdaddr;

	if (sreset) begin
		swraddr_next = 0;
		srdaddr_next = 0;
	end else begin
		if (rd_rdy)
			swraddr_next = swraddr + 10'd1;
		if (srd)
			srdaddr_next = srdaddr + 10'd1;
	end
end

always_ff @(posedge clk) begin
	swraddr <= swraddr_next;
	srdaddr <= srdaddr_next;
end

always_ff @(posedge clk) begin
	if (rd_rdy)
		scratch[swraddr] <= rd_data;
	if (srd)
		srddata <= scratch[srdaddr];
end

reg [31:0]pattern0;
reg pattern0_reset = 0;
reg pattern0_reset_next;
reg pattern0_step = 0;
reg pattern0_step_next;

reg [31:0]pattern1;
reg pattern1_reset = 0;
reg pattern1_reset_next;
reg pattern1_step = 0;
reg pattern1_step_next;

reg [16:0]count = 17'd30000;
reg [16:0]count_next;
wire count_done = count[16];
wire [16:0]count_minus_one = count - 17'd1;

localparam START = 4'd0;
localparam WRITE = 4'd1;
localparam READ  = 4'd2;
localparam HALT  = 4'd3;
localparam VERIFY = 4'd4;
localparam DUMP = 4'd5;
localparam DUMP1 = 4'd6;
localparam DUMP2 = 4'd7;
localparam DUMP3 = 4'd8;

reg [3:0]state = START;
reg [3:0]state_next;

localparam BLOCK = 17'd1023;

`define READX16

always_comb begin
	state_next = state;
	count_next = count;
	rd_addr_next = rd_addr;
	rd_req_next = rd_req;
	rd_len_next = rd_len;
	wr_addr_next = wr_addr;
	wr_data_next = wr_data;
	wr_req_next = wr_req;
	wr_len_next = wr_len;
	pattern0_reset_next = 0;
	pattern1_reset_next = 0;
	pattern0_step_next = 0;
	pattern1_step_next = 0;
	info_next = info;
	info_e_next = 0;
	srd = 0;
	sreset = 0;

	case (state)
	START: if (count_done) begin
		//info_e_next = 1;
		//info_next = 16'h72AA;
		state_next = WRITE;
		count_next = BLOCK;
	end else begin
		count_next = count_minus_one;
	end
	WRITE: if (count_done) begin
		//info_e_next = 1;
		//info_next = 16'h72BB;
		state_next = READ;
`ifdef READX16
		count_next = 63;
`else
		count_next = BLOCK;
`endif
		sreset = 1;
	end else begin
		if (wr_req) begin
			if (wr_ack) begin
				wr_req_next = 0;
				wr_addr_next = wr_addr + 1;
				pattern0_step_next = 1;
				count_next = count_minus_one;
			end
		end else begin
			wr_req_next = 1;
			wr_data_next = pattern0[DMSB:0];
		end
	end
	READ: if (count_done) begin
		//info_e_next = 1;
		//info_next = 16'h72CC;
		state_next = VERIFY;
		count_next = BLOCK;
		srd = 1;
	end else begin
		if (rd_req) begin
			if (rd_ack) begin
				rd_req_next = 0;
`ifdef READX16
				rd_addr_next = rd_addr + 16;
`else
				rd_addr_next = rd_addr + 1;
`endif
				count_next = count_minus_one;
			end
		end else begin
			rd_req_next = 1;
`ifdef READX16
			rd_len_next = 15;
`endif
		end
	end
	VERIFY: if (count_done) begin
		info_e_next = 1;
		info_next = { 8'h71 , rd_addr[17:10] };
		state_next = START;
	end else begin
		if (pattern1[DMSB:0] == srddata) begin
			//info_e_next = 1;
			//info_next = 16'h7011;
			count_next = count_minus_one;
			srd = 1;
			pattern1_step_next = 1;
		end else begin
			info_e_next = 1;
			info_next = 16'h74EE;
			state_next = DUMP;
		end
	end
	DUMP: begin
`ifdef DODUMP
		state_next = DUMP1;
		info_e_next = 1;
		info_next = { 8'h20, pattern1[15:8] };
	end
	DUMP1: begin
		state_next = DUMP2;
		info_e_next = 1;
		info_next = { 8'h20, pattern1[7:0] };
	end
	DUMP2: begin
		state_next = DUMP3;
		info_e_next = 1;
		info_next = { 8'h40, srddata[15:8] };
	end
	DUMP3: begin
		info_e_next = 1;
		info_next = { 8'h40, srddata[7:0] };
`endif
		state_next = HALT;
	end
	HALT: state_next = HALT;	
	default: state_next = HALT;
	endcase
end

reg reset = 1;

always_ff @(posedge clk) begin
	reset <= 0;
	state <= state_next;
	count <= count_next;
	rd_addr <= rd_addr_next;
	rd_req <= rd_req_next;
	rd_len <= rd_len_next;
	wr_addr <= wr_addr_next;
	wr_data <= wr_data_next;
	wr_req <= wr_req_next;
	wr_len <= wr_len_next;
	pattern0_reset <= pattern0_reset_next;
	pattern1_reset <= pattern1_reset_next;
	pattern0_step <= pattern0_step_next;
	pattern1_step <= pattern1_step_next;
	info <= info_next;
	info_e <= info_e_next;
end

xorshift32 xs0(
	.clk(clk),
	.next(pattern0_step_next),
	.reset(pattern0_reset),
	.data(pattern0)
);
xorshift32 xs1(
	.clk(clk),
	.next(pattern1_step_next),
	.reset(pattern1_reset),
	.data(pattern1)
);

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
	.wr_len(wr_len),
	.wr_req(wr_req),
	.wr_ack(wr_ack)
);

endmodule
