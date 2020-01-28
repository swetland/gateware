// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// tRCD (RAS# to CAS# Delay Time)
// Min clocks betwen ACTIVATE of a bank and a READ or WRITE of that bank
//
// tRC (RAS# Cycle Time)
// Min clocks between ACTIVATE of one row in a bank and ACTIVATE of a
// different row in the /same/ bank.  PRECHARGE must happen in between.
//
// tRRD (Row Activate to Row Activate Delay)
// Min time between ACTIVATE of a row in one bank and the ACTIVATE of
// a row in a /different/ bank.
//
// tRP (Precharge to Refresh/Activate)
// Min time between PREFRESH of a bank and REFRESH or ACTIVATE of it
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
	input wire rd_ready,
	output reg [DWIDTH-1:0]rd_data,
	output reg rd_valid = 0,

	input wire [XWIDTH-1:0]wr_addr,
	input wire [DWIDTH-1:0]wr_data,
	input wire wr_valid,
	output reg wr_ready = 0
	);

// sdram addr is wide enough for row + bank
localparam AWIDTH = (ROWBITS + BANKBITS);

// full addr is rowbits + bankbits + colbits wide
localparam XWIDTH = (ROWBITS + BANKBITS + COLBITS);

wire [COLBITS-1:0]wr_col;
wire [BANKBITS-1:0]wr_bank;
wire [ROWBITS-1:0]wr_row;
assign {wr_row, wr_bank, wr_col} = wr_addr;

wire [COLBITS-1:0]rd_col;
wire [BANKBITS-1:0]rd_bank;
wire [ROWBITS-1:0]rd_row;
assign {rd_row, rd_bank, rd_col} = rd_addr;

// high bits for read/write command addresses 
localparam x1_col = { ROWBITS - COLBITS { 1'b1 } };
localparam x0_col = { ROWBITS - COLBITS { 1'b0 } };

reg [DWIDTH-1:0]rd_data_next;
reg rd_valid_next;
reg wr_ready_next;

reg ras_n = 1;
reg cas_n = 1;
reg we_n = 1;
reg [AWIDTH-1:0]addr = 0;
reg [DWIDTH-1:0]data_o = 0;
wire [DWIDTH-1:0]data_i;
reg data_oe = 0;

// next refresh down counter
reg [11:0]refresh = 0;
reg [11:0]refresh_next;
wire [11:0]refresh_sub1;
wire refresh_now;
assign { refresh_now, refresh_sub1 } = { 1'b0, refresh } - 13'd1;

// general purpose down counter
reg [15:0]count = 0;
reg [15:0]count_next;
wire [15:0]count_sub1;
wire count_done;
assign { count_done, count_sub1 } = { 1'b0, count } - 17'd1;

reg [2:0]cmd_next;
reg [AWIDTH-1:0]addr_next;
reg [DWIDTH-1:0]data_o_next;
reg data_oe_next;

localparam START = 4'd0;
localparam INIT0 = 4'd1;
localparam INIT1 = 4'd2;
localparam INIT2 = 4'd3;
localparam INIT3 = 4'd4;
localparam INIT4 = 4'd5;
localparam IDLE = 4'd6;
localparam WACTIVE = 4'd7;
localparam WRITE = 4'd8;
localparam RACTIVE = 4'd9;
localparam READ = 4'd10;
localparam RCAP = 4'd11;

reg [3:0]state = START;
reg [3:0]state_next;

localparam CMD_SET_MODE =  3'b000;  // A0-9 mode, A10+ SBZ
localparam CMD_REFRESH =   3'b001;
localparam CMD_PRECHARGE = 3'b010;  // A10=all, BA*=bankno
localparam CMD_ACTIVATE =  3'b011;  // BA*=bankno
localparam CMD_WRITE =     3'b100;
localparam CMD_READ =      3'b101;
localparam CMD_STOP =      3'b110;
localparam CMD_NOP =       3'b111;

always_comb begin
	state_next = state;
	count_next = count_done ? count : count_sub1;
	refresh_next = refresh_now ? refresh : refresh_sub1;
	cmd_next = CMD_NOP;
	addr_next = addr;
	data_o_next = data_o;
	data_oe_next = data_oe;
	wr_ready_next = 0;
	rd_valid_next = 0;
	rd_data_next = rd_data;

	case (state)
	START: begin
		state_next = INIT0;
		count_next = T_PWR_UP - 1;
	end
	IDLE: if (count_done) begin
		data_oe_next = 0;
		if (refresh_now) begin
			cmd_next = CMD_REFRESH;
			refresh_next = T_RI - 1;
			count_next = T_RC - 1;
		end else if (rd_ready) begin
			state_next = RACTIVE;
			count_next = T_RCD - 1;
			cmd_next = CMD_ACTIVATE;
			addr_next = { rd_bank, rd_row };
		end else if (wr_valid) begin
			state_next = WACTIVE;
			count_next = T_RCD - 1;
			cmd_next = CMD_ACTIVATE;
			addr_next = { wr_bank, wr_row };
			data_oe_next = 1;
		end
	end
	WACTIVE: if (count_done) begin
		state_next = IDLE;
		cmd_next = CMD_WRITE;
		count_next = T_WR + T_RP - 1;
		addr_next = { wr_bank, x1_col, wr_col };
	       	data_o_next = wr_data;
		wr_ready_next = 1;
	end
	RACTIVE: if (count_done) begin
		state_next = READ;
		cmd_next = CMD_READ;
		count_next = T_RCD ;
		addr_next = { rd_bank, x1_col, rd_col };
	end
	READ: if (count_done) begin
		state_next = IDLE;
		count_next = 2; // ??
		rd_data_next = data_i;
		rd_valid_next = 1;
	end
	INIT0: if (count_done) begin
		state_next = INIT1;
		count_next = 2;
		cmd_next = CMD_PRECHARGE;
		addr_next[10] = 1; // ALL
	end
	INIT1: if (count_done) begin
		state_next = INIT2;
		cmd_next = CMD_SET_MODE;
		count_next = T_MRD - 1;
		// r/w burst off, cas lat 3, sequential addr
		addr_next = { {(AWIDTH - 10){1'b0}}, 10'b0000110000};
	end
	INIT2: if (count_done) begin
		state_next = INIT3;
		cmd_next = CMD_REFRESH;
		count_next = T_RC - 1;
	end
	INIT3: if (count_done) begin
		state_next = INIT4;
		cmd_next = CMD_REFRESH;
		count_next = T_RC - 1;
	end
	INIT4: if (count_done) begin
		state_next = IDLE;
		refresh_next = T_RI - 1;
	end
	default: begin
		state_next = START;
	end
	endcase
end

// debug
reg [2:0]cmd = 3'b111;

always_ff @(posedge clk) begin
	state <= state_next;
	count <= count_next;
	refresh <= refresh_next;
	ras_n <= cmd_next[2];
	cas_n <= cmd_next[1];
	we_n <= cmd_next[0];
	cmd <= cmd_next;
	addr <= addr_next;
	data_o <= data_o_next;
	data_oe <= data_oe_next;
	wr_ready <= wr_ready_next;
	rd_valid <= rd_valid_next;
	rd_data <= rd_data_next;
end


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

