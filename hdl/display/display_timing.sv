// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module display_timing #(
	// horizontal timing (all values -1)
	parameter HZNT_FRONT = 15,
	parameter HZNT_SYNC = 95,
	parameter HZNT_BACK = 47,
	parameter HZNT_ACTIVE = 639,

	// vertical timing (all values -1)
	parameter VERT_FRONT = 11,
	parameter VERT_SYNC = 1,
	parameter VERT_BACK = 29,
	parameter VERT_ACTIVE = 479
)(
	input wire clk,

	output wire hsync,
	output wire vsync,
	output wire start_frame,
	output wire start_line,
	output wire pxl_accept,
	output wire [9:0] pxl_x,
	output wire [9:0] pxl_y
);

localparam HS_FRONT = 2'd0;
localparam HS_SYNC = 2'd1;
localparam HS_BACK = 2'd2;
localparam HS_ACTIVE = 2'd3;

localparam VS_FRONT = 2'd0;
localparam VS_SYNC = 2'd1;
localparam VS_BACK = 2'd2;
localparam VS_ACTIVE = 2'd3;

reg [1:0] v_state = VS_FRONT;
reg [1:0] v_state_next;
reg v_sync = 1'b1;
reg v_sync_next;
reg v_active = 1'b0;
reg v_active_next;
reg [9:0] v_count = 10'b0;
reg [9:0] v_count_next;
wire [9:0] v_count_add1;
reg [7:0] v_countdown = VERT_FRONT;
reg [7:0] v_countdown_next;
wire [7:0] v_countdown_sub1;
wire v_countdown_done;

reg [1:0] h_state = HS_FRONT;
reg [1:0] h_state_next;
reg h_sync = 1'b1;
reg h_sync_next;
reg h_active = 1'b0;
reg h_active_next;
reg [9:0] h_count = 10'b0;
reg [9:0] h_count_next;
wire [9:0] h_count_add1;
reg [7:0] h_countdown = HZNT_FRONT;
reg [7:0] h_countdown_next;
wire [7:0] h_countdown_sub1;
wire h_countdown_done;

reg new_line = 1'b0;
reg new_frame = 1'b0;
reg new_line_next;
reg new_frame_next;

assign v_count_add1 = v_count + 9'd1;
assign h_count_add1 = h_count + 9'd1;

assign { h_countdown_done, h_countdown_sub1 } = { 1'b0, h_countdown } - 9'd1;
assign { v_countdown_done, v_countdown_sub1 } = { 1'b0, v_countdown } - 9'd1;

// outputs
assign hsync = h_sync;
assign vsync = v_sync;
assign start_frame = new_frame;
assign start_line = new_line & v_active;
assign pxl_accept = h_active & v_active;
assign pxl_x = h_count;
assign pxl_y = v_count;

always_comb begin
	h_state_next = h_state;
	h_count_next = h_count;
	h_countdown_next = h_countdown;
	h_active_next = h_active;
	h_sync_next = h_sync;
	new_line_next = 1'b0;

	case (h_state)
	HS_FRONT: begin
		if (h_countdown_done) begin
			h_state_next = HS_SYNC;
			h_countdown_next = HZNT_SYNC;
			h_sync_next = 1'b0;
		end else begin
			h_countdown_next = h_countdown_sub1;
		end
	end
	HS_SYNC: begin
		if (h_countdown_done) begin
			h_state_next = HS_BACK;
			h_countdown_next = HZNT_BACK;
			h_sync_next = 1'b1;
		end else begin
			h_countdown_next = h_countdown_sub1;
		end
	end
	HS_BACK: begin
		if (h_countdown_done) begin
			h_state_next = HS_ACTIVE;
			h_countdown_next = HZNT_FRONT;
			h_active_next = 1'b1;
		end else begin
			h_countdown_next = h_countdown_sub1;
		end
	end
	HS_ACTIVE: begin
		if (h_count == HZNT_ACTIVE) begin
			h_state_next = HS_FRONT;
			h_count_next = 0;
			new_line_next = 1'b1;
			h_active_next = 1'b0;
		end else begin
			h_count_next = h_count_add1;
		end
	end
	endcase	
end

always_comb begin
	v_state_next = v_state;
	v_count_next = v_count;
	v_countdown_next = v_countdown;
	v_active_next = v_active;
	v_sync_next = v_sync;
	new_frame_next = 1'b0;

	case (v_state)
	VS_FRONT: begin
		if (v_countdown_done) begin
			v_state_next = VS_SYNC;
			v_countdown_next = VERT_SYNC;
			v_sync_next = 1'b0;
		end else begin
			v_countdown_next = v_countdown_sub1;
		end
	end
	VS_SYNC: begin
		if (v_countdown_done) begin
			v_state_next = VS_BACK;
			v_countdown_next = VERT_BACK;
			v_sync_next = 1'b1;
		end else begin
			v_countdown_next = v_countdown_sub1;
		end
	end
	VS_BACK: begin
		if (v_countdown_done) begin
			v_state_next = VS_ACTIVE;
			v_countdown_next = VERT_FRONT;
			v_active_next = 1'b1;
		end else begin
			v_countdown_next = v_countdown_sub1;
		end
	end
	VS_ACTIVE: begin
		if (v_count == VERT_ACTIVE) begin
			v_state_next = VS_FRONT;
			v_count_next = 0;
			v_active_next = 1'b0;
			new_frame_next = 1'b1;
		end else begin
			v_count_next = v_count_add1;
		end
	end
	endcase	
end

always_ff @(posedge clk) begin
	h_state <= h_state_next;
	h_sync <= h_sync_next;
	h_count <= h_count_next;
	h_countdown <= h_countdown_next;
	h_active <= h_active_next;

	new_line <= new_line_next;
	new_frame <= new_frame_next & new_line_next;

	if (new_line_next) begin
		v_state <= v_state_next;
		v_sync <= v_sync_next;
		v_count <= v_count_next;
		v_countdown <= v_countdown_next;
		v_active <= v_active_next;
	end
end

endmodule
