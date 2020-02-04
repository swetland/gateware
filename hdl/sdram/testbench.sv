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

reg [31:0]addr = 0;
reg [31:0]data = 0;
reg [31:0]addr_next;
reg [31:0]data_next;

reg [31:0]capture = 0;
reg [31:0]capture_next;
reg match = 0;
reg match_next;

// scratch memory to capture back-to-back and burst read results
reg [31:0]scratch[0:511];
reg [8:0]swraddr = 0;
reg [8:0]srdaddr = 0;
reg [31:0]srddata = 0;
reg [8:0]swraddr_next;
reg [8:0]srdaddr_next;

reg sreset = 0;
reg srd = 0;

reg sreset_next;
reg srd_next;

always_comb begin
	swraddr_next = swraddr;
	srdaddr_next = srdaddr;

	if (sreset) begin
		swraddr_next = 0;
		srdaddr_next = 0;
	end else begin
		if (rd_rdy)
			swraddr_next = swraddr + 9'd1;
		if (srd)
			srdaddr_next = srdaddr + 9'd1;
	end
end

always_ff @(posedge clk) begin
	swraddr <= swraddr_next;
	srdaddr <= srdaddr_next;
end

always_ff @(posedge clk) begin
	if (rd_rdy)
		scratch[swraddr] <= { 16'h0, rd_data };
	if (srd_next)
		srddata <= scratch[srdaddr];
end


wire [15:0]xdata;

`ifdef WITH_SCOPE
reg [31:0]scope[0:511];
reg [31:0]scdata = 0;
reg [8:0]scwp = 0;
reg [8:0]scrp = 0;
reg scgo = 0;
reg scgo_next;
reg scrd;

wire [31:0]probe = {
	1'b0, sdram_ras_n, sdram_cas_n, sdram_we_n, sdram_addr, xdata
};

always @(posedge clk) begin
	scwp <= (scgo && (scwp != 511)) ? scwp + 9'd1 : scwp;
	scrp <= scrd ? scrp + 9'd1 : scrp;

	if (scgo)
		scope[scwp] <= probe;
	if (scrd)
		scdata <= scope[scrp];
end
`endif

localparam OP_MISC    = 4'h0; // all 0 is NOP, see MISC_ bits
localparam OP_WR_IMM  = 4'h1; // value to write
localparam OP_WR_PAT  = 4'h2; // count to write pattern0
localparam OP_RD_CHK  = 4'h3; // value to check against
localparam OP_RD_PAT  = 4'h4; // count to read and check vs pattern1
localparam OP_VERIFY  = 4'h5; // count read data to verify vs pattern
localparam OP_RD_FAST = 4'h6; // count fast read
localparam OP_RD_BURST= 4'h7; // count burst read
localparam OP_ADDR    = 4'hA;
localparam OP_DISPLAY = 4'hD; // write arg to vram
localparam OP_WAIT =    4'hF;

localparam MISC_RESET_PAT0 = 0;
localparam MISC_RESET_PAT1 = 1;
localparam MISC_SET_AUTO = 2;
localparam MISC_CLR_AUTO = 3;
localparam MISC_TRIGGER = 29;
localparam MISC_DUMP = 30;
localparam MISC_HALT = 31;

localparam START = 4'd0;
localparam EXEC = 4'd1;
localparam WRITE = 4'd2;
localparam READ = 4'd3;
localparam READ2 = 4'd4;
localparam SHOW = 4'd5;
localparam SHOW2 = 4'd6;
localparam WAIT = 4'd7;
localparam HALT = 4'd8;
localparam READFAST = 4'd9;
localparam READBURST = 4'd12;
localparam VERIFY = 4'd10;
localparam VERIFY2 = 4'd11;
`ifdef WITH_SCOPE
localparam DUMP0 = 4'd12;
localparam DUMP1 = 4'd13;
localparam DUMP2 = 4'd14;
localparam DUMP3 = 4'd15;
`endif

reg auto_inc = 0;
reg auto_inc_next;

wire [31:0]pattern0;
reg pattern0_reset = 0;
reg pattern0_reset_next;
reg pattern0_step = 0;
reg pattern0_step_next;

wire [31:0]pattern1;
reg pattern1_reset = 0;
reg pattern1_reset_next;
reg pattern1_step = 0;
reg pattern1_step_next;
wire p1_match_srddata = (pattern1[15:0] == srddata[15:0]);

reg done_next;
reg error_next;

reg [35:0]insram[0:1023];
reg [35:0]ip = 0;
reg [9:0]pc = 0;

initial $readmemh("hdl/sdram/test.hex", insram);

reg [3:0]state = START;
reg [3:0]state_next;

localparam COUNTMSB = 15;
localparam COUNTONE = 16'd1;
localparam COUNTZERO = 16'd0;
reg [COUNTMSB:0]count = 0;
reg [COUNTMSB:0]count_next;
wire count_is_zero = (count == COUNTZERO);
wire [COUNTMSB:0]count_minus_one = (count - COUNTONE);

always_comb begin
	state_next = state;
	addr_next = addr;
	data_next = data;
	rd_req_next = rd_req;
	wr_req_next = wr_req;
	rd_len_next = rd_len;
	wr_len_next = wr_len;
	count_next = count;
	pattern0_reset_next = 0;
	pattern1_reset_next = 0;
	pattern0_step_next = 0;
	pattern1_step_next = 0;
	auto_inc_next = auto_inc;
	info_next = info;
	info_e_next = 0;
	match_next = match;
	capture_next = capture;
	srd_next = 0;
	sreset_next = 0;
`ifdef WITH_SCOPE
	scgo_next = scgo;
	scrd = 0;
`endif

	case (state)
	START: begin
		state_next = EXEC;
	end
	EXEC: begin
		case (ip[35:32])
		OP_MISC: begin
			if (ip[MISC_RESET_PAT0]) pattern0_reset_next = 1;
			if (ip[MISC_RESET_PAT1]) pattern1_reset_next = 1;
			if (ip[MISC_SET_AUTO]) auto_inc_next = 1;
			if (ip[MISC_CLR_AUTO]) auto_inc_next = 1;
			if (ip[MISC_HALT]) state_next = HALT;
`ifdef WITH_SCOPE
			if (ip[MISC_TRIGGER]) scgo_next = 1;
			if (ip[MISC_DUMP]) begin
				state_next = DUMP0;
				count_next = ip[COUNTMSB:0];
				scrd = 1;
			end
`endif
		end
		OP_WAIT: begin
			state_next = WAIT;
`ifdef verilator
			count_next = 30; 
`else
			count_next = ip[COUNTMSB:0];
`endif
		end
		OP_ADDR: begin
			addr_next = ip[31:0];
		end
		OP_WR_IMM: begin
			state_next = WRITE;
			data_next = ip[31:0];
			wr_req_next = 1;
		end
		OP_WR_PAT: begin
			state_next = WRITE;
			data_next = pattern0;
			count_next = ip[COUNTMSB:0];
			pattern0_step_next = 1;
			wr_req_next = 1;
		end
		OP_RD_CHK: begin
			state_next = READ;
			data_next = ip[31:0];
			rd_req_next = 1;
		end
		OP_RD_PAT: begin
			state_next = READ;
			data_next = pattern1;
			pattern1_step_next = 1;
			rd_req_next = 1;
			count_next = ip[COUNTMSB:0];
		end
		OP_RD_FAST: begin
			state_next = READFAST;
			rd_req_next = 1;
			sreset_next = 1;
			count_next = ip[COUNTMSB:0];
		end
		OP_RD_BURST: begin
			state_next = READBURST;
			rd_req_next = 1;
			rd_len_next = ip[3:0];
			sreset_next = 1;
		end
		OP_DISPLAY: begin
			info_next = ip[15:0];
			info_e_next = 1;
		end
		OP_VERIFY: begin
			state_next = VERIFY;
			count_next = ip[COUNTMSB:0];
			srd_next = 1;
		end
		default: ;
		endcase
	end
	WRITE: if (wr_ack) begin
		if (count_is_zero) begin
			state_next = EXEC;
			wr_req_next = 0;
		end else begin
			count_next = count_minus_one;
			data_next = pattern0;
			pattern0_step_next = 1;
		end
		if (auto_inc) addr_next = addr + 32'd1;
	end
	READ: if (rd_ack) begin
		state_next = READ2;
		rd_req_next = 0;
		if (auto_inc) addr_next = addr + 32'd1;
	end
	READ2: if (rd_rdy) begin
		state_next = SHOW;
		match_next = (data[15:0] == rd_data);
		capture_next = { 16'h0, rd_data };
	end
	READFAST: if (rd_ack) begin
		if (auto_inc) addr_next = addr + 32'd1;
		if (count_is_zero) begin
			state_next = EXEC;
			rd_req_next = 0;
		end else begin
			count_next = count_minus_one;
		end
	end
	READBURST: if (rd_ack) begin
		state_next = EXEC;
		rd_req_next = 0;
		rd_len_next = 0;
	end
	SHOW: begin
		state_next = SHOW2;
		info_next = { match ? 8'h20 : 8'h40, capture[15:8] };
		info_e_next = 1;
	end
	SHOW2: begin
		if (count_is_zero) begin
			state_next = EXEC;
		end else begin
			state_next = READ;
			rd_req_next = 1;
			data_next = pattern1;
			pattern1_step_next = 1;
			count_next = count_minus_one;
		end
		info_next = { match ? 8'h20 : 8'h40, capture[7:0] };
		info_e_next = 1;
	end
	VERIFY: begin
		state_next = VERIFY2;
		info_next = { (srddata[15:0] == pattern1[15:0]) ? 8'h20 : 8'h40, srddata[15:8] };
		info_e_next = 1;
	end
	VERIFY2: begin
		if (count_is_zero) begin
			state_next = EXEC;
		end else begin
			state_next = VERIFY;
			count_next = count_minus_one;
			pattern1_step_next = 1;
			srd_next = 1;
		end
		info_next = { (srddata[15:0] == pattern1[15:0]) ? 8'h20 : 8'h40, srddata[7:0] };
		info_e_next = 1;
	end
`ifdef WITH_SCOPE
	DUMP0: begin
		info_next = { 8'h07, scdata[31:24] };
		info_e_next = 1;
		state_next = DUMP1;
	end
	DUMP1: begin
		info_next = { 8'h70, scdata[23:16] };
		info_e_next = 1;
		state_next = DUMP2;
	end
	DUMP2: begin
		info_next = { 8'h30, scdata[15:8] };
		info_e_next = 1;
		state_next = DUMP3;
	end
	DUMP3: begin
		info_next = { 8'h30, scdata[7:0] };
		info_e_next = 1;
		if (count_is_zero) begin
			state_next = EXEC;
		end else begin
			state_next = DUMP0;
			count_next = count_minus_one;
			scrd = 1;
		end
	end
`endif
	WAIT: if (count_is_zero) begin
		state_next = EXEC;
	end else begin
		count_next = count_minus_one;
	end
	HALT: begin
		state_next = HALT;
`ifdef verilator
		$finish();
`endif
	end
	default: state_next = HALT;
	endcase
end

reg reset = 1;

always_ff @(posedge clk) begin
	reset <= 0;
	state <= state_next;
	count <= count_next;
	if (state_next == EXEC) begin
		ip <= insram[pc];
		pc <= pc + 10'd1;
	end
	addr <= addr_next;
	data <= data_next;
	pattern0_reset <= pattern0_reset_next;
	pattern1_reset <= pattern1_reset_next;
	pattern0_step <= pattern0_step_next;
	pattern1_step <= pattern1_step_next;
	auto_inc <= auto_inc_next;
	info <= info_next;
	info_e <= info_e_next;
	match <= match_next;
	capture <= capture_next;
	wr_req <= wr_req_next;
	rd_req <= rd_req_next;
	wr_len <= wr_len_next;
	rd_len <= rd_len_next;
	srd <= srd_next;
	sreset <= sreset_next;
`ifdef WITH_SCOPE
	scgo <= scgo_next;
`endif
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
	.rd_addr(addr[19:0]),
	.rd_len(rd_len),
	.rd_req(rd_req),
	.rd_ack(rd_ack),
	.rd_data(rd_data),
	.rd_rdy(rd_rdy),

	.wr_addr(addr[19:0]),
	.wr_data(data[15:0]),
	.wr_len(wr_len),
	.wr_req(wr_req),
	.wr_ack(wr_ack)
);

endmodule
