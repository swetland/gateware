// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// tRCD (RAS# to CAS# Delay Time)
// Min clocks betwen ACTIVE of a bank and a READ or WRITE of that bank
//
// tRC (RAS# Cycle Time)
// Min clocks between ACTIVE of one row in a bank and ACTIVE of a
// different row in the /same/ bank.  PRECHARGE must happen in between.
//
// tRRD (Row Activate to Row Activate Delay)
// Min time between ACTIVE of a row in one bank and the ACTIVE of
// a row in a /different/ bank.
//
// tRP (Precharge to Refresh/Activate)
// Min time between PREFRESH of a bank and REFRESH or ACTIVE of it
//
// tWR (Write Recovery Time)
// Min clocks between the last word of a write and PRECHARGE of that bank

module sdram #(
	// Memory Geometry
	parameter BANKBITS = 1,    // 2^BANKBITS banks of
	parameter ROWBITS = 11,    // 2^ROWBITS rows by
	parameter COLBITS = 8,     // 2^COLBITS columns of
	parameter DWIDTH = 16,      // DWIDTH bit wide words

	// Memory Timing
	parameter T_RI = 1900,     // Refresh Interval
	parameter T_RC = 8,        // RAS# Cycle Time
	parameter T_RCD = 3,       // RAS# CAS# Delay
	parameter T_RRD = 3,       // Row Row Delay
	parameter T_RP = 3,        // Precharge to Refresh/Activate
	parameter T_WR = 2,        // Write Recovery TimeA
	parameter T_MRD = 3,       // Mode Register Delay
	parameter T_PWR_UP = 25000 // Power on delay
	) (
	input wire clk,
	input wire reset,
	output wire pin_clk,
	output wire pin_ras_n,
	output wire pin_cas_n,
	output wire pin_we_n,
`ifdef verilator
	input wire [DWIDTH-1:0]pin_data_i,
	output wire [DWIDTH-1:0]pin_data_o,
`else
	inout wire [DWIDTH-1:0]pin_data,
`endif
	output wire [AWIDTH-1:0]pin_addr,

	input wire [XWIDTH-1:0]rd_addr,
	input wire [3:0]rd_len,
	input wire rd_req,
	output reg rd_ack = 0,

	output reg [DWIDTH-1:0]rd_data,
	output reg rd_rdy = 0,

	input wire [XWIDTH-1:0]wr_addr,
	input wire [DWIDTH-1:0]wr_data,
	input wire [3:0]wr_len,
	input wire wr_req,
	output reg wr_ack = 0
	);

// sdram addr is wide enough for row + bank
localparam AWIDTH = (ROWBITS + BANKBITS);

// full addr is rowbits + bankbits + colbits wide
localparam XWIDTH = (ROWBITS + BANKBITS + COLBITS);

localparam BANKCOUNT = (1 << BANKBITS);

integer i; // used by various for loops

// split input address into bank, row, col
wire [BANKBITS-1:0]wr_bank;
wire [ROWBITS-1:0]wr_row;
wire [COLBITS-1:0]wr_col;
assign {wr_row, wr_bank, wr_col} = wr_addr;

// split input address into bank, row, col
wire [BANKBITS-1:0]rd_bank;
wire [ROWBITS-1:0]rd_row;
wire [COLBITS-1:0]rd_col;
assign {rd_row, rd_bank, rd_col} = rd_addr;

// sdram io address management
reg [XWIDTH-1:0]io_addr = 0;
reg [XWIDTH-1:0]io_addr_next;

wire [COLBITS-1:0]io_col;
wire [BANKBITS-1:0]io_bank;
wire [ROWBITS-1:0]io_row;
assign {io_row, io_bank, io_col} = io_addr;
wire [COLBITS-1:0]io_col_add1 = io_col + {{COLBITS-1{1'b0}},1'b1};

reg [DWIDTH-1:0]rd_data_next;
reg rd_ack_next;
reg rd_rdy_next;
reg wr_ack_next;

// signals to sdram_glue module
wire ras_n;
wire cas_n;
wire we_n;
wire [AWIDTH-1:0]addr;
wire [DWIDTH-1:0]data_i;
reg [DWIDTH-1:0]data_o = 0;
reg data_oe = 0;

reg [DWIDTH-1:0]data_o_next;
reg data_oe_next;

reg [2:0]cmd = 3'b111;
reg [2:0]cmd_next;

// next refresh down counter
reg [15:0]refresh = T_PWR_UP;
reg [15:0]refresh_next;
wire [15:0]refresh_sub1 = refresh - 16'd1;
wire refresh_done = refresh[15];

// sdram bank state
reg bank_active[0:BANKCOUNT-1];
reg bank_active_next[0:BANKCOUNT-1];
reg [ROWBITS-1:0]bank_row[0:BANKCOUNT-1];
reg [ROWBITS-1:0]bank_row_next[0:BANKCOUNT-1];

// state machine state
localparam START = 4'd0;
localparam IDLE = 4'd1;
localparam INIT0 = 4'd2;
localparam INIT1 = 4'd3;
localparam INIT2 = 4'd4;
localparam REFRESH = 4'd5;
localparam ACTIVE = 4'd6;
localparam READ = 4'd7;
localparam WRITE = 4'd8;
localparam START_READ = 4'd9;
localparam START_WRITE = 4'd10;

reg [3:0]state = START;
reg [3:0]state_next;

// sdram commands
localparam CMD_SET_MODE =  3'b000;  // A0-9 mode, A10+ SBZ
localparam CMD_REFRESH =   3'b001;
localparam CMD_PRECHARGE = 3'b010;  // BA*=bankno, A10=ALL
localparam CMD_ACTIVE =    3'b011;  // BA*=bankno, A*=ROW
localparam CMD_WRITE =     3'b100;  // BA*=bankno, A10=AP, COLADDR
localparam CMD_READ =      3'b101;  // BA*=bankno, A10=AP, COLADDR
localparam CMD_STOP =      3'b110;
localparam CMD_NOP =       3'b111;

// TODO CL2 vs CL3 configurability here and elsewhere

reg [3:0]rd_pipe_rdy = 0;
reg [3:0]rd_pipe_bsy = 0;
reg [3:0]rd_pipe_rdy_next;
reg [3:0]rd_pipe_bsy_next;

reg [3:0]burst = 0;
reg [3:0]burst_next;
wire [3:0]burst_sub1;
wire burst_done;
assign { burst_done, burst_sub1 } = { 1'b0, burst } - 5'd1;

reg io_sel_a10 = 0;
reg io_sel_a10_next;
reg io_sel_row = 0;
reg io_sel_row_next;

// general purpose down counter
//reg [4:0]count = 0;
//reg [4:0]count_next;
//wire [4:0]count_sub1 = count - 5'd1;
//wire count_done = count[4];

reg [8:0]count = 0;
reg [8:0]count_next;
reg count_done = 1;
reg count_done_next;

reg io_do_rd = 0;
reg io_do_rd_next;

always_comb begin
	state_next = state;
//	count_next = count_done ? count : count_sub1;
	refresh_next = refresh_done ? refresh : refresh_sub1;
	cmd_next = CMD_NOP;
	data_o_next = data_o;
	data_oe_next = 0;
	wr_ack_next = 0;
	rd_rdy_next = 0;
	rd_ack_next = 0;
	rd_data_next = rd_data;
	burst_next = burst;
	io_addr_next = io_addr;
	io_do_rd_next = io_do_rd;
	io_sel_a10_next = io_sel_a10;
	io_sel_row_next = io_sel_row;

	count_done_next = count_done | count[0];
	count_next = { 1'b0, count[8:1] };

	for (i = 0; i < BANKCOUNT; i++) begin
		bank_active_next[i] = bank_active[i];
		bank_row_next[i] = bank_row[i];
	end

	// read pipe regs track inbound read data (rdy)
	// and hold off writes (bsy) to avoid bus conflict
	rd_pipe_rdy_next = { 1'b0, rd_pipe_rdy[3:1] };
	rd_pipe_bsy_next = { 1'b0, rd_pipe_bsy[3:1] };
	
	if (rd_pipe_rdy[0]) begin
		rd_rdy_next = 1;
		rd_data_next = data_i;
	end

	if (count_done) // state can only advance if counter is 0
	case (state)
	START: begin
		refresh_next = T_PWR_UP;
		state_next = INIT0;
	end
	IDLE: begin
		data_oe_next = 0;
		if (refresh_done) begin
			// refresh counter has expired, precharge all and refresh
			state_next = REFRESH;
			cmd_next = CMD_PRECHARGE;
			io_sel_row_next = 0;
			io_sel_a10_next = 1; // ALL BANKS
			//count_next = T_RP - 2;
			count_next[T_RP-2] = 1; count_done_next = 0;
		end else if (rd_req) begin
			io_do_rd_next = 1;
			io_addr_next = rd_addr;
			burst_next = rd_len;
			state_next = START_READ;
			rd_ack_next = 1;
		end else if (wr_req) begin
			io_do_rd_next = 0;
			io_addr_next = wr_addr;
			data_o_next = wr_data;
			burst_next = wr_len;
			state_next = START_WRITE;
			wr_ack_next = 1;
		end
	end
	START_READ: begin
		if (!bank_active[io_bank] || (bank_row[io_bank] != io_row)) begin
			state_next = ACTIVE;
			cmd_next = CMD_PRECHARGE;
			io_sel_row_next = 0; // column addr
			io_sel_a10_next = 0; // one bank only
			//count_next = T_RP - 2;
			count_next[T_RP-2] = 1; count_done_next = 0;
		end else begin
			cmd_next = CMD_READ;
			io_sel_row_next = 0; // column addr
			io_sel_a10_next = 0; // no auto precharge
			rd_pipe_rdy_next = { 1'b1, rd_pipe_rdy[3:1] };
			rd_pipe_bsy_next = 4'b1111;
			state_next = (burst != 4'd0) ? READ : IDLE;
		end
	end
	START_WRITE: if (!rd_pipe_bsy[0]) begin
		if (!bank_active[io_bank] || (bank_row[io_bank] != io_row)) begin
			state_next = ACTIVE;
			// precharge one bank (a10=0)
			cmd_next = CMD_PRECHARGE;
			io_sel_row_next = 0; // column addr
			io_sel_a10_next = 0; // one bank only
			//count_next = T_RP - 2;
			count_next[T_RP-2] = 1; count_done_next = 0;
		end else begin
			cmd_next = CMD_WRITE;
			io_sel_row_next = 0; // column addr
			io_sel_a10_next = 0; // no auto precharge
			data_oe_next = 1;
			state_next = (burst != 4'd0) ? WRITE : IDLE;
		end
	end
	ACTIVE: begin
		state_next = io_do_rd ? START_READ : START_WRITE;
		//count_next = T_RCD - 2;
		count_next[T_RCD-2] = 1; count_done_next = 0;
		cmd_next = CMD_ACTIVE;
		io_sel_row_next = 1; // row address
		bank_active_next[io_bank] = 1;
		bank_row_next[io_bank] = io_row;
	end
	READ: begin
		if (burst_done) begin
			state_next = IDLE;
		end else begin
			burst_next = burst_sub1;
		end
		// column addressing pre-selected from initial read
		io_addr_next[COLBITS-1:0] = io_col_add1;
		cmd_next = CMD_READ;
		rd_pipe_rdy_next = { 1'b1, rd_pipe_rdy[3:1] };
		rd_pipe_bsy_next = 4'b1111;
	end
	WRITE: begin
		if (burst_done) begin
			state_next = IDLE;
		end else begin
			burst_next = burst_sub1;
		end
		// column addressing pre-selected from initial write
		io_addr_next[COLBITS-1:0] = io_col_add1;
		cmd_next = CMD_WRITE;
		data_oe_next = 1;
	end
	INIT0: if (refresh_done) begin
		state_next = INIT1;
		//count_next = 2;
		count_next[2] = 1; count_done_next = 0;
		cmd_next = CMD_PRECHARGE;
		io_sel_row_next = 0; // column addressing
		io_sel_a10_next = 1; // ALL BANKS
	end
	INIT1: begin
		state_next = INIT2;
		cmd_next = CMD_SET_MODE;
		//count_next = T_MRD - 2;
		count_next[T_MRD-2] = 1; count_done_next = 0;
		// r/w burst off, cas lat 3, sequential addr
		io_addr_next[XWIDTH-1:COLBITS] = { {(AWIDTH - 10){1'b0}}, 10'b0000110000};
		io_sel_row_next = 1; // row addressing
	end
	INIT2: begin
		state_next = REFRESH;
		cmd_next = CMD_REFRESH;
		//count_next = T_RC - 2;
		count_next[T_RC-2] = 1; count_done_next = 0;
	end
	REFRESH: begin
		state_next = IDLE;
		cmd_next = CMD_REFRESH;
		//count_next = T_RC - 2;
		count_next[T_RC-2] = 1; count_done_next = 0;
		refresh_next = T_RI - 1;

		// we got here after a precharge all
		for (i = 0; i < BANKCOUNT; i++)
			bank_active_next[i] = 0;
	end
	default: begin
		//state_next = START;
	end
	endcase
end

always_ff @(posedge clk) begin
	state <= reset ? START : state_next;
	count <= count_next;
	count_done <= count_done_next;
	refresh <= refresh_next;
	cmd <= cmd_next;
	io_do_rd <= io_do_rd_next;
	io_sel_a10 <= io_sel_a10_next;
	io_sel_row <= io_sel_row_next;
	io_addr <= io_addr_next;
	data_o <= data_o_next;
	data_oe <= data_oe_next;
	wr_ack <= wr_ack_next;
	rd_ack <= rd_ack_next;
	rd_rdy <= rd_rdy_next;
	rd_data <= rd_data_next;
	for (i = 0; i < BANKCOUNT; i++) begin
		bank_active[i] <= bank_active_next[i];
		bank_row[i] <= bank_row_next[i];
	end
	rd_pipe_rdy <= rd_pipe_rdy_next;
	rd_pipe_bsy <= rd_pipe_bsy_next;
end

assign { ras_n, cas_n, we_n } = cmd;

wire [(ROWBITS-COLBITS)-1:0]io_misc = {{(ROWBITS-COLBITS)-1{1'b0}}, io_sel_a10 } << (10 - COLBITS);
wire [ROWBITS-1:0]io_low = io_sel_row ? io_row : { io_misc, io_col };
assign addr = { io_bank, io_low };

`ifdef verilator
assign pin_clk = clk;
assign pin_ras_n = ras_n;
assign pin_cas_n = cas_n;
assign pin_we_n = we_n;
assign pin_addr = addr;
assign pin_data_o = data_o;
assign data_i = pin_data_i;

`else
sdram_glue #(
	.AWIDTH(AWIDTH),
	.DWIDTH(DWIDTH)
	) glue (
	.clk(clk),
	.pin_clk(pin_clk),
	.pin_ras_n(pin_ras_n),
	.pin_cas_n(pin_cas_n),
	.pin_we_n(pin_we_n),
	.pin_addr(pin_addr),
	.pin_data(pin_data),
	.ras_n(ras_n),
	.cas_n(cas_n),
	.we_n(we_n),
	.addr(addr),
	.data_i(data_i),
	.data_o(data_o),
	.data_oe(data_oe)
);
`endif

endmodule

