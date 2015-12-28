// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module cpu(
	input clk,
	output [15:0]mem_raddr_o,
	input [15:0]mem_rdata_i,
	output [15:0]mem_waddr_o,
	output [15:0]mem_wdata_o,
	output mem_wr_o,
	output mem_rd_o
	);

parameter RWIDTH = 16;
parameter SWIDTH = 4;

localparam AWIDTH = 16;
localparam DWIDTH = 16;
localparam IWIDTH = 16;

// control signals
reg do_fetch;
reg do_load;
reg do_store;
reg do_wreg;
reg do_load_adata;
reg do_load_bdata;
reg do_load_flags;
reg do_load_wsel;
reg do_load_alu_op;
reg [2:0]do_sel_bdata;
reg [1:0]do_sel_wsel;
reg [1:0]do_sel_branch;
reg do_alu_op_mov; // override ALU opcode
reg do_1mem_0alu; // select input to regs.wdata
reg do_exe_alu;
reg do_exe_load;
reg do_dec_imm;

wire ir_cond_true;

// processor registers
reg [AWIDTH-1:0]pc = 16'b0;
reg [3:0]flags = 4'b0;
reg [15:0]ir = 16'b0;
reg ir_valid = 1'b0;
reg ir_loading = 1'b0;

reg [15:0]ir_next;
reg ir_valid_next;
reg ir_loading_next;

// registers that allow/disallow EXEC/LOAD and IMMEDIATE
reg exe_alu = 1'b0;
reg exe_load = 1'b0;
reg dec_imm = 1'b0;

// registers loaded during DECODE for use in EXEC/LOAD
reg [3:0]alu_op = 4'b0;
reg [RWIDTH-1:0]adata = 16'b0;
reg [RWIDTH-1:0]bdata = 16'b0;
reg [3:0]wsel = 4'b0;

// in/out of alu
wire [RWIDTH-1:0]alu_adata = adata;
wire [RWIDTH-1:0]alu_bdata = bdata;
wire [RWIDTH-1:0]alu_rdata;
wire [3:0]alu_flags;

// in/out of reg file
wire [3:0]regs_asel = ir[11:8];
wire [3:0]regs_bsel = ir[7:4];
wire [RWIDTH-1:0]regs_wdata = do_1mem_0alu ? { {(RWIDTH-DWIDTH){1'b0}}, mem_rdata_i } : alu_rdata;
wire [RWIDTH-1:0]regs_adata;
wire [RWIDTH-1:0]regs_bdata;

// values computed 
wire [RWIDTH-1:0]ir_imm_s4mem = { {(RWIDTH-4){ir[3]}}, ir[3:0] };
wire [RWIDTH-1:0]ir_imm_s4alu = { {(RWIDTH-4){ir[7]}}, ir[7:4] };
wire [RWIDTH-1:0]ir_imm_s8 = { {(RWIDTH-8){ir[7]}}, ir[7:0] };
wire [RWIDTH-1:0]ir_imm_s12 = { {(RWIDTH-12){ir[11]}}, ir[11:0] };

wire [RWIDTH-1:0]load_store_addr = regs_bdata + ir_imm_s4mem;

wire [AWIDTH-1:0]inst_addr = do_load_pc ? pc_next : pc;

// memory interface
assign mem_wr_o = do_store;
assign mem_rd_o = 1;
assign mem_raddr_o = do_load ? load_store_addr[AWIDTH-1:0] : inst_addr;
assign mem_waddr_o = load_store_addr[AWIDTH-1:0];
assign mem_wdata_o = regs_adata[AWIDTH-1:0];


localparam BR_NONE    = 2'b00; // PC + 1    the normal fetch
localparam BR_REL_S8  = 2'b01; // PC + S8   a short branch
localparam BR_REL_S12 = 2'b10; // PC + S12  a long branch
localparam BR_ABS_REG = 2'b11; // [RB]      an indirect branch

reg [AWIDTH-1:0]pc_next;
always @(*) begin
	case (do_sel_branch)
	BR_NONE:    pc_next = pc + { {(AWIDTH-1){1'b0}}, 1'b1 };
	BR_REL_S8:  pc_next = pc + ir_imm_s8;
	BR_REL_S12: pc_next = pc + ir_imm_s12;
	BR_ABS_REG: pc_next = regs_bdata;
	endcase
end

reg do_load_pc;

// lw r3, [r0]
// mov r0, #0xDEAD
always @(*) begin
	ir_next = ir;
	ir_valid_next = ir_valid;
	ir_loading_next = ir_loading;

	do_load_pc = 1'b0;

	// we try to read an instruction every cycle
	// unless we're pre-empted by a data load
	//XXX don't issue a read if we know it's useless?
	ir_loading_next = ~do_load;

	if (do_sel_branch != BR_NONE) begin
		// branch is always highest priority
		ir_valid_next = 1'b0;
		do_load_pc = 1'b1;
	end else if (ir_loading) begin
		// we've read an instruction
		if ((~ir_valid) | do_fetch) begin
			// ir was empty or is being consumed
			// fill it with the just-read instruction
			// and advance the pc
			ir_next = mem_rdata_i;
			ir_valid_next = 1'b1;
			do_load_pc = 1'b1;
		end else if (do_fetch) begin
			// ir has been consumed if it was non-empty
			ir_valid_next = 1'b0;
		end
	end else begin
		// not loading
		if (do_fetch) begin
			ir_valid_next = 1'b0;
		end
	end
end

always @(posedge clk) begin
/*
	if (cpu_reset) begin
		pc <= {AWIDTH{1'b0}};
		ir_valid <= 1'b0;
		ir_loading <= 1'b0;
	end else begin
*/
		pc <= do_load_pc ? pc_next : pc;
		ir_valid <= ir_valid_next;
		ir_loading <= ir_loading_next;
//	end
	ir <= ir_next;
end

localparam BDATA_RB = 3'b000;
localparam BDATA_IR = 3'b001;
localparam BDATA_PC = 3'b010;
localparam BDATA_S4 = 3'b011; 
localparam BDATA_S8 = 3'b111;

reg [RWIDTH-1:0]bdata_mux;
always @(*) begin
	case (do_sel_bdata[1:0])
	2'b00: bdata_mux = regs_bdata;
	2'b01: bdata_mux = ir;
	2'b10: bdata_mux = pc;
	2'b11: bdata_mux = do_sel_bdata[2] ? ir_imm_s8 : ir_imm_s4alu;
	endcase
end

localparam WSEL_RA = 2'b00;
localparam WSEL_RB = 2'b01;
localparam WSEL_OP = 2'b10;
localparam WSEL_LR = 2'b11;

reg [3:0]wsel_mux;
always @(*) begin
	case (do_sel_wsel)
	WSEL_RA: wsel_mux = ir[11:8];
	WSEL_RB: wsel_mux = ir[7:4];
	WSEL_OP: wsel_mux = { 2'b0, ir[13:12] };
	WSEL_LR: wsel_mux = 4'd14;
	endcase
end

always @(*) begin
	// decode stage
	do_fetch =       1'b1;
	do_load =        1'b0;
	do_store =       1'b0;
	do_alu_op_mov =  1'b0;
	do_load_adata =  1'b1;
	do_load_bdata =  1'b1;
	do_load_wsel =   1'b1;
	do_load_alu_op = 1'b1;
	do_sel_branch =  BR_NONE;
	do_sel_bdata =   BDATA_RB;
	do_sel_wsel =    WSEL_RA;

	do_dec_imm =     1'b0;
	do_exe_alu =     1'b0;
	do_exe_load =    1'b0;

	// load/exec stage
	do_wreg =        1'b0;
	do_1mem_0alu =   1'b0;
	do_load_flags =  1'b0;

	casez ({ir_valid, dec_imm, ir[15:12]})
	6'b0?????: begin
		// ir is invalid (wait state)
		// try again next cycle
		do_dec_imm = dec_imm;
		// don't modify any state
		// otherwise we could break wide ops
		do_load_adata = 1'b0;
		do_load_bdata = 1'b0;
		do_load_wsel = 1'b0;
		do_load_alu_op = 1'b0;
	end
	6'b11????: begin // alu Rb, Ra, imm16  (second half)
		do_exe_alu = 1'b1;
		do_sel_bdata = BDATA_IR;
		do_load_bdata = 1'b1;
		// some data we carry from first half of instr
		do_load_adata = 1'b0;
		do_load_wsel = 1'b0;
		do_load_alu_op = 1'b0;
	end
	6'b100000: begin // alu Ra, Ra, Rb
		do_exe_alu = 1'b1;
	end
	6'b100001: begin // mov immediate
		do_exe_alu = 1'b1;
		do_alu_op_mov = 1'b1;
		do_sel_bdata = BDATA_S8;
	end
	6'b100010: begin // alu Ra, Ra, imm4
		do_exe_alu = 1'b1;
		do_sel_bdata = BDATA_S4;
	end
	6'b100011: begin // alu Rb, Ra, imm16  (first half)
		do_dec_imm = 1'b1;
		do_sel_wsel = WSEL_RB;
	end
	6'b1001??: begin // alu Rd, Ra, Rb
		do_exe_alu = 1'b1;
		do_sel_wsel = WSEL_OP;
	end
	6'b101000: begin // lw Ra, [Rb, imm]
		do_exe_load = 1'b1;
		do_load = 1'b1;
		do_alu_op_mov = 1'b1;
	end
	6'b101001: begin // sw Ra, [Rb, imm]
		do_store = 1'b1;
	end
	6'b101010: begin // bC imm8
		if (ir_cond_true) begin
			do_sel_branch = BR_REL_S8;
		end
	end
	6'b101011: begin // bC [Rb] / blC [Rb]
		if (ir_cond_true) begin
			do_sel_branch = BR_ABS_REG;
			if (ir[3]) begin
				// arrange to write PC to LR
				do_exe_alu = 1'b1;
				do_sel_bdata = BDATA_PC;
				do_alu_op_mov = 1'b1;
				do_sel_wsel = WSEL_LR;
			end
		end
	end
	6'b101100: begin // b rel12
		do_sel_branch = BR_REL_S12;
	end
	6'b101101: begin // bl rel12
		do_sel_branch = BR_REL_S12;
		// arrange to write PC to LR
		do_exe_alu = 1'b1;
		do_sel_bdata = BDATA_PC;
		do_alu_op_mov = 1'b1;
		do_sel_wsel = WSEL_LR;
	end
	default: begin
		// treat undefined as NOP
	end
	endcase

	// ALU / LOAD stage
	if (exe_load) begin
		do_wreg = 1'b1;
		do_1mem_0alu = 1'b1;
	end else if (exe_alu) begin
		do_wreg = 1'b1;
		do_load_flags = 1'b1;
		do_1mem_0alu = 1'b0;
	end
end

always @(posedge clk) begin
	flags <= do_load_flags ? alu_flags : flags;
	alu_op <= do_load_alu_op ? (do_alu_op_mov ? 4'b0000 : ir[3:0]) : alu_op;
	adata <= do_load_adata ? regs_adata : adata;
	bdata <= do_load_bdata ? bdata_mux : bdata;
	wsel <= do_load_wsel ? wsel_mux : wsel;
	exe_alu <= do_exe_alu;
	exe_load <= do_exe_load;
	dec_imm <= do_dec_imm;
end

wire [DWIDTH-1:0]raw_regs_adata;
wire [DWIDTH-1:0]raw_regs_bdata;

regfile #(
	.DWIDTH(RWIDTH)
	)regs(
	.clk(clk),
	.asel(regs_asel),
	.bsel(regs_bsel),
	.adata(raw_regs_adata),
	.bdata(raw_regs_bdata),
	.wsel(wsel),
	.wdata(regs_wdata),
	.wreg(do_wreg)
	);

`define BYPASS
`ifdef BYPASS
wire bypass_a = do_wreg & (wsel == ir[11:8]);
wire bypass_b = do_wreg & (wsel == ir[7:4]);
assign regs_adata = bypass_a ? regs_wdata : raw_regs_adata;
assign regs_bdata = bypass_b ? regs_wdata : raw_regs_bdata;
`else
assign regs_adata = raw_regs_adata;
assign regs_bdata = raw_regs_bdata;
`endif

alu #(
	.DWIDTH(RWIDTH),
	.SWIDTH(SWIDTH)
	)alu0(
	.op(alu_op),
	.adata(alu_adata),
	.bdata(alu_bdata),
	.rdata(alu_rdata),
	.flags_o(alu_flags),
	.flags_i(flags)
	);

// when ALU is writing flags (do_load_flags),
// use the newly written value instead of the register
check_cond check(
`ifdef BYPASS
	.flags_i(do_load_flags ? alu_flags : flags),
`else
	.flags_i(flags),
`endif
	.cond_i(ir[11:8]),
	.is_true_o(ir_cond_true)
	);

endmodule

