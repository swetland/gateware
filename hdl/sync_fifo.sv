// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// basic fifo with power-of-two storage elements

// bypass register allows written data to be available
// the cycle after a write in all cases.
`define SYNC_FIFO_WITH_BYPASS

module sync_fifo #(
	// fifo entry data width in bits
	parameter WIDTH = 8,

	// fifo depth in 2 ^ DEPTH
	parameter DEPTH = 8
	) (
	input wire clk,

	input wire [WIDTH-1:0]wr_data,
	input wire wr_valid,
	output reg wr_ready = 0,

	output wire [WIDTH-1:0]rd_data,
	output reg rd_valid = 0,
	input wire rd_ready
);

localparam PTRONE = { {DEPTH{1'b0}}, 1'b1 };

wire do_wr = (wr_valid & wr_ready);
wire do_rd = (rd_valid & rd_ready);

// pointers are one bit wider so the high bit
// can help compute full / empty
reg [DEPTH:0]wr_ptr = 0;
reg [DEPTH:0]rd_ptr = 0;

// prepare the new r/w pointer values
wire [DEPTH:0]wr_ptr_next = do_wr ? (wr_ptr + PTRONE) : wr_ptr;
wire [DEPTH:0]rd_ptr_next = do_rd ? (rd_ptr + PTRONE) : rd_ptr;

// compute the new full/empty states
wire full_or_empty_next = (rd_ptr_next[DEPTH-1:0] == wr_ptr_next[DEPTH-1:0]);
wire full_next = full_or_empty_next & (rd_ptr_next[DEPTH] != wr_ptr_next[DEPTH]);
wire empty_next = full_or_empty_next & (rd_ptr_next[DEPTH] == wr_ptr_next[DEPTH]);
wire one_next = ((wr_ptr_next - rd_ptr_next) == PTRONE);

localparam EMPTY = 2'd0;
localparam ONE   = 2'd1;
localparam MANY  = 2'd2;
localparam FULL  = 2'd3;

reg [1:0]state = EMPTY;
reg [1:0]state_next;
reg rd_valid_next;
reg wr_ready_next;

`ifdef SYNC_FIFO_WITH_BYPASS
reg [WIDTH-1:0]bypass;
reg use_bypass = 0;
reg use_bypass_next;
`endif

always_comb begin
	state_next = state;
	rd_valid_next = rd_valid;
	wr_ready_next = wr_ready;
`ifdef SYNC_FIFO_WITH_BYPASS
	use_bypass_next = 0;
`endif

	case (state)
	EMPTY: begin
		wr_ready_next = 1;
		if (do_wr) begin
			state_next = ONE;
`ifdef SYNC_FIFO_WITH_BYPASS
			rd_valid_next = 1;
			use_bypass_next = 1;
`endif
		end
	end
	ONE: begin
		if (do_rd & do_wr) begin
`ifdef SYNC_FIFO_WITH_BYPASS
			use_bypass_next = 1;
`else
			rd_valid_next = 0;
`endif
		end else if (do_rd) begin
			state_next = EMPTY;
			rd_valid_next = 0;
		end else if (do_wr) begin
			state_next = MANY;
			rd_valid_next = 1;
		end else begin
			rd_valid_next = 1;
		end
	end
	MANY: begin
		if (one_next) begin
			state_next = ONE;
		end else if (full_next) begin
			state_next = FULL;
			wr_ready_next = 0;
		end
	end
	FULL: begin
		if (do_rd) begin
			state_next = MANY;
			wr_ready_next = 1;
		end
	end
	endcase
end

always_ff @(posedge clk) begin
	state <= state_next;
	rd_ptr <= rd_ptr_next;
	wr_ptr <= wr_ptr_next;
	wr_ready <= wr_ready_next;
	rd_valid <= rd_valid_next;
`ifdef SYNC_FIFO_WITH_BYPASS
	bypass <= use_bypass_next ? wr_data : bypass;
	use_bypass <= use_bypass_next;
`endif
end

// fifo storage
reg [WIDTH-1:0]memory[0:2**DEPTH-1];
reg [WIDTH-1:0]data;

always_ff @(posedge clk) begin
	if (wr_valid & wr_ready)
		memory[wr_ptr[DEPTH-1:0]] <= wr_data;

	data <= memory[rd_ptr_next[DEPTH-1:0]];
end

`ifdef SYNC_FIFO_WITH_BYPASS
assign rd_data = use_bypass ? bypass : data;
`else
assign rd_data = data;
`endif

endmodule

