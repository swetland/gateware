// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

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

// Control Signal Constants

localparam SEL_ALU_OP_ADD  = 2'b00;
localparam SEL_ALU_OP_MHI  = 2'b01;
localparam SEL_ALU_OP_FUNC = 2'b10;
localparam SEL_ALU_OP_SHFT = 2'b11;

localparam SEL_XDATA_ADATA = 1'b0;
localparam SEL_XDATA_PC    = 1'b1;

localparam SEL_YDATA_BDATA = 1'b0;
localparam SEL_YDATA_IMM   = 1'b1;

localparam SEL_REG_B_IR_B = 1'b0;
localparam SEL_REG_B_IR_C = 1'b1;

localparam SEL_REG_W_IR_C = 1'b0;
localparam SEL_REG_W_R7   = 1'b1;

localparam SEL_BR_ALU     = 1'b0;
localparam SEL_BR_BDATA   = 1'b1;


wire ex_do_branch;
reg [15:0]ex_branch_tgt;

wire de_pause;

// Instruction Fetch (if)
reg [15:0]if_pc = 16'd0;

assign ins_rd_addr = if_pc_next;
assign ins_rd_req = 1'b1;

wire [15:0]if_pc_plus_1 = if_pc + 16'h0001;

wire [15:0]if_de_ir = ins_rd_data;
wire if_de_ir_valid = ins_rd_rdy & (~ex_do_branch);

reg [15:0]if_pc_next;
always_comb begin
	if (reset) begin
		if_pc_next = 16'd0;
	end else if (ex_do_branch) begin
		if_pc_next = ex_branch_tgt;
	end else if (if_de_ir_valid & (~de_pause)) begin
		if_pc_next = if_pc_plus_1;
	end else begin
		if_pc_next = if_pc;
	end
end

always_ff @(posedge clk) begin
	if_pc <= if_pc_next;
end

// Instruction Decode (de)

reg [15:0]de_ir = 16'd0;
reg [15:0]de_pc_plus_1 = 16'd0;
reg de_ir_valid = 1'b0;

// Immediate Forms
// si7  siiiiiixxxxxxxxx -> ssssssssssiiiiii
// si9  siiiiiixjjxxxxxx -> ssssssssjjiiiiii
// si10 siiiiiijjjxxxxxx -> sssssssjjjiiiiii
// si12 siiiiiijjjkkxxxx -> ssssskkjjjiiiiii

wire de_ir_imm_s       = de_ir[15];
wire [5:0]de_ir_imm_i  = de_ir[14:9];
wire [2:0]de_ir_imm_j  = de_ir[8:6];
wire [1:0]de_ir_imm_k  = de_ir[5:4];
wire [3:0]de_ir_sel_f  = de_ir[15:12];
wire [2:0]de_ir_sel_b  = de_ir[11:9];
wire [2:0]de_ir_sel_a  = de_ir[8:6];
wire [2:0]de_ir_sel_c  = de_ir[5:3];
wire [2:0]de_ir_opcode = de_ir[2:0];
wire [5:0]de_ir_imm_u  = { de_ir[14:12], de_ir[8:6] };

reg [15:0]de_ir_imm;
always_comb begin
	casez (de_ir_opcode)
	3'b??1: de_ir_imm = { {10{de_ir_imm_s}}, de_ir_imm_i }; // si7
	3'b?00: de_ir_imm = { {8{de_ir_imm_s}}, de_ir_imm_j[1:0], de_ir_imm_i }; // si9
	3'b010: de_ir_imm = { {7{de_ir_imm_s}}, de_ir_imm_j, de_ir_imm_i }; // si10
	3'b110: de_ir_imm = { {5{de_ir_imm_s}}, de_ir_imm_k, de_ir_imm_j, de_ir_imm_i }; // si12
	endcase
end

reg [1:0]de_sel_alu_op;   // choose alu op SEL_ALU_OP_*
reg de_sel_xdata;         // choose alu x input SEL_XDATA_*
reg de_sel_ydata;         // choose alu y input SEL_YDATA_*
reg de_sel_reg_b;         // choose reg b addr SEL_REG_B_*
reg de_sel_reg_w;         // choose reg w addr SEL_REG_W_*
reg de_sel_br;            // choose branch tgt SEL_BR_*
reg de_do_zero_xdata;     // force alu x input to 16'h0
reg de_do_cond_zero;      // branch condition (0=NZ, 1=Z)

reg de_do_wr_reg;         // write alu result to register
reg de_do_wr_link;        // write PC+1 to R7
reg de_do_rd_mem;         // read memory during ex
reg de_do_wr_mem;         // write memory during ex
reg de_do_uncon_branch;   // execute unconditional branch
reg de_do_cond_branch;    // execute conditional branch

reg de_using_reg_a;
reg de_using_reg_b;

reg [3:0]de_alu_op;
reg [2:0]de_regs_bsel;
reg [2:0]de_regs_wsel;
reg [2:0]de_regs_asel;
always_comb begin
	case (de_sel_alu_op)
	SEL_ALU_OP_ADD:  de_alu_op = 4'b0100;
	SEL_ALU_OP_MHI:  de_alu_op = 4'b1111;
	SEL_ALU_OP_FUNC: de_alu_op = de_ir_sel_f;
	SEL_ALU_OP_SHFT: de_alu_op = {2'b10,de_ir_sel_f[1:0]};
	endcase
	case (de_sel_reg_b)
	SEL_REG_B_IR_B: de_regs_bsel = de_ir_sel_b;
	SEL_REG_B_IR_C: de_regs_bsel = de_ir_sel_c;
	endcase
	case (de_sel_reg_w)
	SEL_REG_W_IR_C: de_regs_wsel = de_ir_sel_c;
	SEL_REG_W_R7:   de_regs_wsel = 3'd7;
	endcase
	de_regs_asel = de_ir_sel_a;
end

always_ff @(posedge clk) begin
	if (~de_pause) begin
		if (if_de_ir_valid) begin
			de_ir <= if_de_ir;
			de_pc_plus_1 <= if_pc_plus_1;
		end
		de_ir_valid <= if_de_ir_valid;
	end
end

wire de_hzd_reg_a;
wire de_hzd_reg_b;

always_comb begin
	de_sel_alu_op = SEL_ALU_OP_ADD;
	de_sel_xdata = SEL_XDATA_ADATA;
	de_sel_ydata = SEL_YDATA_BDATA;
	de_sel_reg_b = SEL_REG_B_IR_B;
	de_sel_reg_w = SEL_REG_W_IR_C;
	de_sel_br = SEL_BR_ALU;
	de_do_zero_xdata = 1'b0;
	de_do_cond_zero = 1'b0;
	de_do_wr_reg = 1'b0;
	de_do_wr_link = 1'b0;
	de_do_rd_mem = 1'b0;
	de_do_wr_mem = 1'b0;
	de_do_uncon_branch = 1'b0;
	de_do_cond_branch = 1'b0;
	de_using_reg_a = 1'b0;
	de_using_reg_b = 1'b0;
	case (de_ir_opcode)
	3'b000: begin // ALU Rc, Ra, Rb
		de_sel_alu_op = SEL_ALU_OP_FUNC;
		de_sel_reg_b = SEL_REG_B_IR_B;
		de_sel_xdata = SEL_XDATA_ADATA;
		de_sel_ydata = SEL_YDATA_BDATA;
		de_sel_reg_w = SEL_REG_W_IR_C;
		de_do_wr_reg = 1'b1;
		de_using_reg_a = 1'b1;
		de_using_reg_b = 1'b1;
	end
	3'b001: begin // ADD Rc, Ra, si7
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_xdata = SEL_XDATA_ADATA;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_reg_w = SEL_REG_W_IR_C;
		de_do_wr_reg = 1'b1;
		de_using_reg_a = 1'b1;
		de_using_reg_b = 1'b1;
	end
	3'b010: begin // MOV Rc, si10
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_reg_w = SEL_REG_W_IR_C;
		de_sel_reg_b = SEL_REG_B_IR_C;
		de_do_zero_xdata = 1'b1;
		de_do_wr_reg = 1'b1;
	end
	3'b011: begin // LW Rc, [Ra, si7]
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_xdata = SEL_XDATA_ADATA;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_reg_w = SEL_REG_W_IR_C;
		de_do_rd_mem = 1'b1;
		de_using_reg_a = 1'b1;
	end
	3'b100: begin // BZ/BNZ Rc, si9
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_xdata = SEL_XDATA_PC;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_reg_b = SEL_REG_B_IR_C;
		de_sel_br = SEL_BR_ALU;
		de_do_cond_branch = 1'b1;
		de_do_cond_zero = de_ir[8];
		de_using_reg_b = 1'b1;
	end
	3'b101: begin // SW Rc, [Ra, si7]
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_xdata = SEL_XDATA_ADATA;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_reg_b = SEL_REG_B_IR_C;
		de_do_wr_mem = 1'b1;
		de_using_reg_a = 1'b1;
		de_using_reg_b = 1'b1;
	end
	3'b110: begin // B/BL si12
		de_sel_alu_op = SEL_ALU_OP_ADD;
		de_sel_xdata = SEL_XDATA_PC;
		de_sel_ydata = SEL_YDATA_IMM;
		de_sel_br = SEL_BR_ALU;
		de_do_wr_link = de_ir[3];
		de_do_uncon_branch = 1'b1;
	end
	3'b111: begin
		if (de_ir[15]) begin // MHI Rc, Ra, si7
			de_sel_alu_op = SEL_ALU_OP_MHI;
			de_sel_xdata = SEL_XDATA_ADATA;
			de_sel_ydata = SEL_YDATA_IMM;
			de_sel_reg_w = SEL_REG_W_IR_C;
			de_do_wr_reg = 1'b1;
			de_using_reg_a = 1'b1;
		end else case (de_ir[11:9])
		3'b000: begin // B/BL Ra
			de_sel_br = SEL_BR_BDATA;
			de_do_wr_link = de_ir[3];
			de_do_uncon_branch = 1'b1;
			de_using_reg_a = 1'b1;
		end
		3'b001: begin // NOP
		end
		3'b010: begin // RSV0 (NOP)
			//TODO: FAULT
		end
		3'b011: begin // RSV1 (NOP)
			//TODO: FAULT
		end
		3'b100: begin // LC Rc, u6
			//TODO: CTRL REGS
		end
		3'b101: begin // SC Rc, u6
			//TODO: CTRL REGS
		end
		3'b110: begin // SHIFT Rc, Ra, 1
			// imm7 bit0 chooses shift-by-1
			de_sel_alu_op = SEL_ALU_OP_SHFT;
			de_sel_xdata = SEL_XDATA_ADATA;
			de_sel_ydata = SEL_YDATA_IMM;
			de_sel_reg_w = SEL_REG_W_IR_C;
			de_do_wr_reg = 1'b1;
			de_using_reg_a = 1'b1;
		end
		3'b111: begin // SHIFT Rc, Ra, 4
			// imm7 bit0 chooses shift-by-4
			de_sel_alu_op = SEL_ALU_OP_SHFT;
			de_sel_xdata = SEL_XDATA_ADATA;
			de_sel_ydata = SEL_YDATA_IMM;
			de_sel_reg_w = SEL_REG_W_IR_C;
			de_do_wr_reg = 1'b1;
			de_using_reg_a = 1'b1;
		end
		endcase
	end
	endcase
end

wire [15:0]regs_ex_adata;
wire [15:0]regs_ex_bdata;

reg wb_regs_do_wr_reg = 1'b0;
reg wb_regs_do_wr_dat = 1'b0;
reg [2:0]wb_regs_wsel = 3'b0;
reg [15:0]wb_regs_wdata = 16'd0;

wire [15:0]regs_wdata = wb_regs_do_wr_dat ? dat_rd_data : wb_regs_wdata;

cpu16_regs regs(
	.clk(clk),
	.asel(de_regs_asel),
	.adata(regs_ex_adata),
	.bsel(de_regs_bsel),
	.bdata(regs_ex_bdata),
	.wreg(wb_regs_do_wr_reg | wb_regs_do_wr_dat),
	.wsel(wb_regs_wsel),
	.wdata(regs_wdata)
	);

// Execute (ex)

reg [15:0]ex_adata;
reg [15:0]ex_bdata;
reg [15:0]alu_ex_rdata;

reg [15:0]ex_pc_plus_1 = 16'd0;
reg [15:0]ex_imm = 16'd0;

reg [3:0]ex_alu_op = 4'd0;
reg [2:0]ex_regs_wsel = 3'd0;
reg ex_sel_xdata = 1'b0;
reg ex_sel_ydata = 1'b0;

reg ex_sel_br = 1'b0;
reg ex_do_zero_xdata = 1'b0;
reg ex_do_cond_zero = 1'b0;

reg ex_do_wr_reg = 1'b0;
reg ex_do_wr_link = 1'b0;
reg ex_do_rd_mem = 1'b0;
reg ex_do_wr_mem = 1'b0;
reg ex_do_uncon_branch = 1'b0;
reg ex_do_cond_branch = 1'b0;

reg ex_valid = 1'b0;

always_ff @(posedge clk) begin
	ex_pc_plus_1 <= de_pc_plus_1;
	ex_imm <= de_ir_imm;
	ex_alu_op <= de_alu_op;
	ex_regs_wsel <= de_regs_wsel;
	ex_sel_xdata <= de_sel_xdata;
	ex_sel_ydata <= de_sel_ydata;
	ex_sel_br <= de_sel_br;
	ex_do_cond_zero <= de_do_cond_zero;
	ex_valid <= de_ir_valid;
	if ((~de_ir_valid) | de_pause | ex_do_branch) begin
		ex_do_zero_xdata <= 1'b0;
		ex_do_wr_reg <= 1'b0;
		ex_do_wr_link <= 1'b0;
		ex_do_rd_mem <= 1'b0;
		ex_do_wr_mem <= 1'b0;
		ex_do_uncon_branch <= 1'b0;
		ex_do_cond_branch <= 1'b0;
	end else begin
		ex_do_zero_xdata <= de_do_zero_xdata;
		ex_do_wr_reg <= de_do_wr_reg;
		ex_do_wr_link <= de_do_wr_link;
		ex_do_rd_mem <= de_do_rd_mem;
		ex_do_wr_mem <= de_do_wr_mem;
		ex_do_uncon_branch <= de_do_uncon_branch;
		ex_do_cond_branch <= de_do_cond_branch;
	end
end

wire ex_is_cond_zero = (regs_ex_bdata == 16'd0);

assign ex_do_branch = ex_do_uncon_branch | (ex_do_cond_branch & (ex_do_cond_zero == ex_is_cond_zero));

reg [15:0]alu_x;
reg [15:0]alu_y;

always_comb begin
	if (ex_do_zero_xdata) begin
		alu_x = 16'd0;
	end else begin
		case (ex_sel_xdata)
		SEL_XDATA_ADATA: alu_x = regs_ex_adata;
		SEL_XDATA_PC:    alu_x = ex_pc_plus_1;
		endcase
	end
	case (ex_sel_ydata)
	SEL_YDATA_BDATA: alu_y = regs_ex_bdata;
	SEL_YDATA_IMM:   alu_y = ex_imm;
	endcase
	case (ex_sel_br)
	SEL_BR_ALU:   ex_branch_tgt = alu_ex_rdata;
	SEL_BR_BDATA: ex_branch_tgt = regs_ex_bdata;
	endcase
end

cpu16_alu alu(
	.op(ex_alu_op),
	.x(alu_x),
	.y(alu_y),
	.r(alu_ex_rdata)
	);

wire [15:0]ex_regs_wdata = ex_do_wr_link ? ex_pc_plus_1 : alu_ex_rdata;

assign dat_rw_addr = alu_ex_rdata;
assign dat_wr_data = regs_ex_bdata;
assign dat_rd_req = ex_do_rd_mem;
assign dat_wr_req = ex_do_wr_mem;

// Write Back (wb)

always_ff @(posedge clk) begin
	wb_regs_wsel <= ex_do_wr_link ? 3'd7 : ex_regs_wsel;
	wb_regs_wdata <= ex_regs_wdata;
	if (!ex_valid) begin
		wb_regs_do_wr_reg <= 1'b0;
		wb_regs_do_wr_dat <= 1'b0;
	end else begin
		wb_regs_do_wr_reg <= ex_do_wr_reg | (ex_do_wr_link & ex_do_branch) | ex_do_rd_mem;
		wb_regs_do_wr_dat <= ex_do_rd_mem;
	end

end

assign de_hzd_reg_a = de_using_reg_a & (
	(ex_do_wr_reg & (de_regs_asel == ex_regs_wsel)) |
	(wb_regs_do_wr_reg & (de_regs_asel == wb_regs_wsel)));
assign de_hzd_reg_b = de_using_reg_b & (
	(ex_do_wr_reg & (de_regs_bsel == ex_regs_wsel)) |
	(wb_regs_do_wr_reg & (de_regs_bsel == wb_regs_wsel)));
assign de_pause = de_hzd_reg_a | de_hzd_reg_b;

// ---- SIMULATION DEBUG ASSIST ----

`ifdef verilator
reg [15:0]dbg_addr = 16'd0;
wire [31:0]ir_dbg_dis;
reg [31:0]ex_dbg_dis = 32'd0;

assign ir_dbg_dis = { de_ir, dbg_addr };

always_ff @(posedge clk) begin
	dbg_addr <= if_pc;
	ex_dbg_dis <= ir_dbg_dis;
end
`endif

endmodule

