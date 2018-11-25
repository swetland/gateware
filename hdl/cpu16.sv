// Copyright 2015, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`timescale 1ns / 1ps

module cpu16(
        input clk,
        output [15:0]ins_rd_addr,
        input [15:0]ins_rd_data,
	output ins_rd_req,
	input ins_rd_rdy,

	output [15:0]dat_rw_addr,
	output [15:0]dat_wr_data,
	input [15:0]dat_rd_data,
	output dat_rd_req,
	output dat_wr_req,
	input dat_rd_rdy,
	input dat_wr_rdy,

	input reset
        );

localparam INS_NOP = 16'h0001;

// ---- FETCH ----
reg [15:0]pc_next;
reg [15:0]ir_next;
reg ir_valid_next;

reg [15:0]pc = 16'd0;
reg [15:0]ir = 16'd0;
reg ir_valid = 1'b0;

assign ins_rd_addr = pc_next;
assign ins_rd_req = 1'b1;

always_comb begin
	if (reset) begin
		pc_next = 16'h0000;
	end else if (ex_do_branch_imm) begin
		pc_next = ex_branch_tgt;
	end else if (ins_rd_rdy) begin
		pc_next = pc + 16'h0001;
	end else begin
		pc_next = pc;
	end
	ir_next = ins_rd_rdy ? ins_rd_data : INS_NOP;
	ir_valid_next = ins_rd_rdy;
end

always_ff @(posedge clk) begin
	pc <= pc_next;
	ir <= ir_next;
	ir_valid <= ir_valid_next;
end

// ---- DECODE ----
reg [11:0]de_ext = 12'b0;
reg de_ext_rdy = 1'b0;

// s6   alu-reg-imm  load/store
// s7   pc-rel-cond-branch
// s9   mov-imm
// s11  pc-rel-branch
// s12  ext

// fields decoded from instruction
wire [15:0]ir_imm_s6_raw = { {11 {ir[15]}}, ir[14:10] };
wire [15:0]ir_imm_s7 = { {10 {ir[15]}}, ir[6], ir[14:10] };
wire [15:0]ir_imm_s9_raw = { {8 {ir[15]}}, ir[9:7], ir[14:10] };
wire [15:0]ir_imm_s11 = { {6 {ir[15]}}, ir[8:4], ir[14:10] };
wire [15:0]ir_imm_s12 = { {5 {ir[15]}}, ir[9:4], ir[14:10] };
wire [2:0]ir_csel = ir[6:4];
wire [2:0]ir_asel = ir[9:7];
wire [2:0]ir_bsel = ir[12:10];
wire [2:0]ir_alu_op = ir[3] ? ir[2:0] : ir[15:13];
wire [3:0]ir_opcode = ir[3:0];

reg [11:0]ir_ext_imm = 12'b0;
reg ir_ext_rdy = 1'b0;

wire [15:0]ir_imm_s6 = { (ir_ext_rdy ? ir_ext_imm : ir_imm_s6_raw[15:4]), ir_imm_s6_raw[3:0] };
wire [15:0]ir_imm_s9 = { (ir_ext_rdy ? ir_ext_imm : ir_imm_s9_raw[15:4]), ir_imm_s9_raw[3:0] };

// control signals
reg do_wreg_alu; // write from alu
reg do_wreg_mem; // write from memory
reg do_adata_zero; // pass 0 to alu.xdata (instead of adata)
reg do_bdata_imm; // pass imm to alu.ydata (instead of bdata)
reg do_wr_link;    // write PC + 1 to LR
reg do_branch_imm; // branch to imm
reg do_branch_reg; // branch to reg + imm
reg do_branch_cond; // branch if condition met
reg do_branch_zero; // condition zero(1) or notzero(0)
reg do_use_imm9_or_imm6;
reg do_mem_read;
reg do_mem_write;
reg do_set_ext;

always_comb begin
	do_wreg_alu = 1'b0;
	do_wreg_mem = 1'b0;
	do_adata_zero = 1'b0;
	do_bdata_imm = 1'b0;
	do_wr_link = 1'b0;
	do_branch_imm = 1'b0;
	do_branch_reg = 1'b0;
	do_branch_cond = 1'b0;
	do_branch_zero = 1'b0;
	do_use_imm9_or_imm6 = 1'b0;
	do_mem_read = 1'b0;
	do_mem_write = 1'b0;
	do_set_ext = 1'b0;

	casez (ir_opcode)
	4'b0000: begin // alu Rc, Ra, Rb
		do_wreg_alu = 1'b1;
	end
	4'b0001: begin // expansion (nop)
	end
	4'b0010: begin // ext si12
		do_set_ext = 1'b1;
	end
	4'b0011: begin // mov Rc, si9
		do_wreg_alu = 1'b1;
		do_adata_zero = 1'b1;
		do_bdata_imm = 1'b1;
		do_use_imm9_or_imm6 = 1'b1;
	end
	4'b0100: begin // lw Rc, [Ra, si6]
		do_mem_read = 1'b1;
		do_use_imm9_or_imm6 = 1'b0;
	end
	4'b0101: begin // sw Rc, [Ra, si6]
		do_mem_write = 1'b1;
		do_use_imm9_or_imm6 = 1'b0;
	end
	4'b0110: begin // b imm12 / bl imm12
		do_branch_imm = 1'b1;
		do_wr_link = ir[9];
	end
	4'b0111: begin // BZ/BNZ/B/BL
		if (ir[5]) begin // b Ra / bl Ra
			do_branch_reg = 1'b1;
			do_wr_link = ir[4];
		end else begin // bz imm7 / bnz imm7
			do_branch_cond = 1'b1;
			do_branch_zero = ~ir[4];
		end
	end
	4'b1???: begin // alu Rc, Ra, si6
		do_wreg_alu = 1'b1;
		do_bdata_imm = 1'b1;
		do_use_imm9_or_imm6 = 1'b0;
	end
	endcase
end

always_ff @(posedge clk) begin
	if (ir_valid)
		ir_ext_rdy <= do_set_ext;
	if (ir_valid & do_set_ext)
		ir_ext_imm <= ir_imm_s12[11:0];
end

wire [15:0]ex_adata;
wire [15:0]ex_bdata;
wire [15:0]ex_alu_rdata;

regs16 regs(
	.clk(clk),
	.asel(ir_asel),
	.bsel(do_mem_write ? ir_csel : ir_bsel),
	.wsel(ex_wsel),
	.wreg(ex_do_wreg_alu),
	.adata(ex_adata),
	.bdata(ex_bdata),
	.wdata(ex_alu_rdata)
	);

// ---- EXECUTE ----

reg [15:0]ex_branch_tgt = 16'b0;
reg [2:0]ex_alu_op = 3'b0;
reg [2:0]ex_wsel = 3'b0;
reg ex_do_wreg_alu = 1'b0;
reg ex_do_wreg_mem = 1'b0;
reg ex_do_adata_zero = 1'b0;
reg ex_do_bdata_imm = 1'b0;
reg ex_do_wr_link = 1'b0;
reg ex_do_branch_imm = 1'b0;
reg ex_do_branch_reg = 1'b0;
reg ex_do_branch_cond = 1'b0;
reg ex_do_branch_zero = 1'b0;
reg ex_do_mem_read = 1'b0;
reg ex_do_mem_write = 1'b0;

reg [15:0]ex_imm = 16'b0;

always_ff @(posedge clk) begin
	// for mem-read or mem-write we use the ALU for Ra + imm7
	ex_alu_op <= (do_adata_zero | do_mem_read | do_mem_write) ? 3'b0 : ir_alu_op;
	ex_wsel <= do_wr_link ? 3'd7 : ir_csel;
	ex_branch_tgt <= pc + (do_branch_imm ? ir_imm_s11 : ir_imm_s7);
	ex_do_wreg_alu <= do_wreg_alu;
	ex_do_wreg_mem <= do_wreg_mem;
	ex_do_adata_zero <= do_adata_zero;
	ex_do_bdata_imm <= do_bdata_imm;
	ex_do_wr_link <= do_wr_link;
	ex_do_branch_imm <= do_branch_imm;
	ex_do_branch_reg <= do_branch_reg;
	ex_do_branch_cond <= do_branch_cond;
	ex_do_branch_zero <= do_branch_zero;
	ex_do_mem_read = do_mem_read;
	ex_do_mem_write = do_mem_write;
	ex_imm <= (do_mem_read | do_mem_write) ? ir_imm_s7 : (do_use_imm9_or_imm6 ? ir_imm_s9 : ir_imm_s6);
end


alu16 alu(
	.op(ex_alu_op),
	.xdata(ex_do_adata_zero ? 16'b0 : ex_adata),
	.ydata((ex_do_mem_read | ex_do_mem_write | ex_do_bdata_imm) ? ex_imm : ex_bdata),
	.rdata(ex_alu_rdata)
	);

assign dat_rw_addr = ex_alu_rdata;
assign dat_wr_data = ex_bdata;
assign dat_rd_req = ex_do_mem_read;
assign dat_wr_req = ex_do_mem_write;

// ---- SIMULATION DEBUG ASSIST ----

`ifdef verilator
reg [15:0]dbg_addr = 16'd0;
wire [47:0]ir_dbg_dis;
reg [47:0]ex_dbg_dis = 48'd0;

assign ir_dbg_dis = { ir, 3'b0, ir_ext_rdy, ir_ext_imm, dbg_addr };

always_ff @(posedge clk) begin
	dbg_addr <= pc;
	ex_dbg_dis <= ir_dbg_dis;
end
`endif

endmodule

module regs16(
	input clk,
	input [2:0]asel,
	input [2:0]bsel,
	input [2:0]wsel,
	input wreg,
	input [15:0]wdata,
	output [15:0]adata,
	output [15:0]bdata
	);

reg [15:0]rmem[0:7];
reg [15:0]areg;
reg [15:0]breg;

always_ff @(posedge clk) begin
	if (wreg)
		rmem[wsel] <= wdata;
	areg <= rmem[asel];
	breg <= rmem[bsel];
end

assign adata = areg;
assign bdata = breg;

endmodule


module alu16(
	input [2:0]op,
	input [15:0]xdata,
	input [15:0]ydata,
	output [15:0]rdata
	);

reg [15:0]r;

always_comb begin
	case (op)
	3'b000: r = xdata + ydata;
	3'b001: r = xdata - ydata;
	3'b010: r = xdata & ydata;
	3'b011: r = xdata | ydata;
	3'b100: r = xdata ^ ydata;
	3'b101: r = { {15 {1'b0}}, xdata < ydata };
	3'b110: r = { {15 {1'b0}}, xdata >= ydata };
	3'b111: r = xdata * ydata;
	endcase
end

assign rdata = r;

endmodule

