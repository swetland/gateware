// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module cpu #(
	parameter RWIDTH = 16,
	parameter SWIDTH = 4
	)(
	input clk,
	output [15:0]mem_raddr_o,
	input [15:0]mem_rdata_i,
	output [15:0]mem_waddr_o,
	output [15:0]mem_wdata_o,
	output mem_wr_o,
	output mem_rd_o
	);

localparam AWIDTH = 16;
localparam DWIDTH = 16;
localparam IWIDTH = 16;

// control signals
reg do_fetch;
reg do_load;
reg do_store;
wire do_wreg;
reg [1:0]do_sel_bdata;
reg [1:0]do_sel_wsel;
reg [1:0]do_sel_branch;
reg [1:0]do_sel_alu_op;
reg do_exe_alu;
reg do_exe_load;
reg do_exe_branch;

// processor registers
reg [AWIDTH-1:0]pc = 16'b0;
reg [15:0]ir = 16'b0;
reg ir_valid = 1'b0;
reg ir_loading = 1'b0;

reg [15:0]ir_next;
reg ir_valid_next;
reg ir_loading_next;

// registers that allow/disallow EXEC/LOAD and IMMEDIATE
reg exe_alu = 1'b0;
reg exe_load = 1'b0;
reg exe_branch = 1'b0;

// registers loaded during DECODE for use in EXEC/LOAD
reg [3:0]alu_op = 4'b0;
reg [RWIDTH-1:0]adata = 16'b0;
reg [RWIDTH-1:0]bdata = 16'b0;
reg [3:0]wsel = 4'b0;

// in/out of alu
wire [RWIDTH-1:0]alu_rdata;

// values computed 
wire [3:0]ir_asel = ir[7:4];
wire [3:0]ir_bsel = ir[11:8];
wire [RWIDTH-1:0]ir_imm_s4 =  { {(RWIDTH-3) {ir[15]}}, ir[14:12] };
wire [RWIDTH-1:0]ir_imm_s8 =  { {(RWIDTH-7) {ir[15]}}, ir[14:8] };
wire [RWIDTH-1:0]ir_imm_s12 = { {(RWIDTH-11){ir[15]}}, ir[14:4] };

// in/out of reg file
wire [3:0]regs_asel = ir_asel;
wire [3:0]regs_bsel = ir_bsel;
wire [RWIDTH-1:0]regs_wdata = exe_load ? { {(RWIDTH-DWIDTH){1'b0}}, mem_rdata_i } : alu_rdata;
wire [RWIDTH-1:0]regs_adata;
wire [RWIDTH-1:0]regs_bdata;

wire [RWIDTH-1:0]load_store_addr = regs_bdata + ir_imm_s4;

wire [AWIDTH-1:0]inst_addr = do_load_pc ? pc_next : pc;

reg [AWIDTH-1:0]branch_target;

localparam BR_REL_S8  = 2'b00; // PC + S8   a short branch
localparam BR_REL_S12 = 2'b01; // PC + S12  a long branch
localparam BR_ABS_RB  = 2'b10; // RB        an indirect branch

wire [AWIDTH-1:0]branch_imm = do_sel_branch[0] ? ir_imm_s12 : ir_imm_s8;
wire [AWIDTH-1:0]branch_target_next = do_sel_branch[1] ? regs_bdata : (pc + branch_imm);

// memory interface
assign mem_wr_o = do_store;
assign mem_rd_o = 1;
assign mem_raddr_o = do_load ? load_store_addr[AWIDTH-1:0] : inst_addr;
assign mem_waddr_o = load_store_addr[AWIDTH-1:0];
assign mem_wdata_o = regs_adata[AWIDTH-1:0];

wire [AWIDTH-1:0]pc_next = exe_branch ? branch_target : (pc + 16'd1);

reg do_load_pc;

always @(*) begin
	ir_next = ir;
	ir_valid_next = ir_valid;
	ir_loading_next = ir_loading;

	do_load_pc = 1'b0;

	// we try to read an instruction every cycle
	// unless we're pre-empted by a data load
	//XXX don't issue a read if we know it's useless?
	ir_loading_next = ~do_load;

	if (exe_branch) begin
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
	pc <= do_load_pc ? pc_next : pc;
	ir_valid <= ir_valid_next;
	ir_loading <= ir_loading_next;
	ir <= ir_next;
end

localparam BDATA_RB = 2'b00;
localparam BDATA_PC = 2'b01;
localparam BDATA_S4 = 2'b10; 
localparam BDATA_S8 = 2'b11;
reg [RWIDTH-1:0]bdata_mux;
always @(*) begin
	case (do_sel_bdata)
	BDATA_RB: bdata_mux = regs_bdata;
	BDATA_PC: bdata_mux = pc;
	BDATA_S4: bdata_mux = ir_imm_s4;
	BDATA_S8: bdata_mux = ir_imm_s8;
	endcase
end

localparam WSEL_RA = 2'b00;
localparam WSEL_RB = 2'b01;
localparam WSEL_OP = 2'b10;
localparam WSEL_LR = 2'b11;
reg [3:0]wsel_mux;
always @(*) begin
	case (do_sel_wsel)
	WSEL_RA: wsel_mux = ir[7:4];
	WSEL_RB: wsel_mux = ir[11:8];
	WSEL_OP: wsel_mux = { 2'b0, ir[1:0] };
	WSEL_LR: wsel_mux = 4'd14;
	endcase
end

localparam ALU_MOV = 2'b00;
localparam ALU_MHI = 2'b01;
localparam ALU_FN_HI = 2'b10;
localparam ALU_FN_LO = 2'b11;
reg [3:0]alu_op_mux;
always @(*) begin
	case (do_sel_alu_op)
	ALU_MOV:   alu_op_mux = 4'b0000;
	ALU_MHI:   alu_op_mux = 4'b0111;
	ALU_FN_HI: alu_op_mux = ir[15:12];
	ALU_FN_LO: alu_op_mux = ir[11:8];
	endcase
end

wire regs_adata_zero = (regs_adata == 16'd0);

assign do_wreg = exe_alu | exe_load;

//`define WITH_BYPASS

localparam USE_RA =    2'b10;
localparam USE_RB =    2'b01;
localparam USE_RA_RB = 2'b11;
localparam USE_NONE =  2'b00;
reg [1:0]using;
wire conflict_a = (wsel == ir_asel) & using[1];
wire conflict_b = (wsel == ir_bsel) & using[0];

always @(*) begin
	// decode stage
	do_fetch =       1'b1;
	do_load =        1'b0;
	do_store =       1'b0;
	do_sel_branch =  BR_ABS_RB;
	do_sel_bdata =   BDATA_RB;
	do_sel_wsel =    WSEL_RA;
	do_sel_alu_op =  ALU_MOV;

	do_exe_alu =     1'b0;
	do_exe_load =    1'b0;
	do_exe_branch =  1'b0;

	using = USE_RA_RB;

	if (exe_branch) begin
		do_fetch = 1'b0;
	end
`ifndef WITH_BYPASS
	else if (exe_alu | exe_load) begin
		do_fetch = ~(conflict_a | conflict_b);
	end
`endif

	casez (ir[3:0])
	4'b0000: begin // mov Ra, imm
		using = USE_NONE;
		do_exe_alu = 1'b1;
		do_sel_alu_op = ALU_MOV;
		do_sel_wsel = WSEL_RA;
		do_sel_bdata = BDATA_S8;
	end
	4'b0001: begin // mhi Ra, imm
		using = USE_RA;
		do_exe_alu = 1'b1;
		do_sel_alu_op = ALU_MHI;
		do_sel_wsel = WSEL_RA;
		do_sel_bdata = BDATA_S8;
	end
	4'b0010: begin // alu Ra, Ra, Rb
		using = USE_RA_RB;
		do_exe_alu = 1'b1;
		do_sel_alu_op = ALU_FN_HI;
		do_sel_wsel = WSEL_RA;
		do_sel_bdata = BDATA_RB;
	end
	4'b0011: begin // alu Ra, Ra, imm4
		using = USE_RA;
		do_exe_alu = 1'b1;
		do_sel_alu_op = ALU_FN_LO;
		do_sel_wsel = WSEL_RA;
		do_sel_bdata = BDATA_S4;
	end
	4'b01??: begin // alu Rd, Ra, Rb
		using = USE_RA_RB;
		do_exe_alu = 1'b1;
		do_sel_alu_op = ALU_FN_HI;
		do_sel_wsel = WSEL_OP;
		do_sel_bdata = BDATA_RB;
	end
	4'b1000: begin // lw Ra, [Rb, imm]
		using = USE_RB;
		do_exe_load = 1'b1;
		do_load = ir_valid;
	end
	4'b1001: begin // sw Ra, [Rb, imm]
		using = USE_RA_RB;
		do_store = ir_valid;
	end
	4'b1010: begin // bnz Ra, rel8
		using = USE_RA;
		do_exe_branch = ~regs_adata_zero;
		do_sel_branch = BR_REL_S8;
	end
	4'b1011: begin // bz Ra, rel8
		using = USE_RA;
		do_exe_branch = regs_adata_zero;
		do_sel_branch = BR_REL_S8;
	end
	4'b1100: begin // b rel12
		using = USE_NONE;
		do_exe_branch = 1'b1;
		do_sel_branch = BR_REL_S12;
	end
	4'b1101: begin // bl rel12
		using = USE_NONE;
		do_exe_alu = 1'b1;
		do_exe_branch = 1'b1;
		do_sel_branch = BR_REL_S12;
		do_sel_alu_op = ALU_MOV;
		do_sel_bdata = BDATA_PC;
		do_sel_wsel = WSEL_LR;
	end
	4'b1110: begin
		if (ir[15:13] == 3'b000) begin // b Rb / bl Rb
			using = USE_RB;
			do_exe_branch = 1'b1;
			do_sel_branch = BR_ABS_RB;
			if (ir[12]) begin
				do_exe_alu = 1'b1;
				do_sel_alu_op = ALU_MOV;
				do_sel_bdata = BDATA_PC;
				do_sel_wsel = WSEL_LR;
			end
		end
	end
	default: begin
		// treat undefined as NOP
	end
	endcase
end

always @(posedge clk) begin
	alu_op <= alu_op_mux;
	adata <= regs_adata;
	bdata <= bdata_mux;
	wsel <= wsel_mux;
	exe_alu <= ir_valid & do_fetch & do_exe_alu;
	exe_load <= ir_valid & do_fetch & do_exe_load;
	exe_branch <= ir_valid & do_fetch & do_exe_branch;
	branch_target <= branch_target_next;

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

`ifdef WITH_BYPASS
wire bypass_a = do_wreg & (wsel == ir_asel) & (~exe_load);
wire bypass_b = do_wreg & (wsel == ir_bsel) & (~exe_load);
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
	.adata(adata),
	.bdata(bdata),
	.rdata(alu_rdata)
	);

endmodule

