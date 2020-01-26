// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module testbench(
	input wire clk,
	output reg error = 0,
	output reg done = 0
);

wire [31:0]wr_data;
wire wr_ready;
reg wr_valid = 0;

wire [31:0]rd_data;
wire rd_valid;
reg rd_ready = 0;

wire [31:0]chk_data;

reg [31:0]count = 0;
reg [31:0]rd_count = 0;

reg [31:0]rd_count_n;
reg rd_ready_n;
reg wr_valid_n;
reg done_n;
reg error_n;

always_comb begin
	rd_count_n = rd_count;
	rd_ready_n = rd_ready;
	wr_valid_n = wr_valid;
	done_n = 0;
	error_n = 0;

	$display("%3d: W(%08x) %s %s --> R(%08x) %s %s   C(%08x)  RX(%3d)",
		count,
		wr_data, wr_valid ? "V" : "-", wr_ready ? "r" : "-",
		rd_data, rd_valid ? "v" : "-", rd_ready ? "R" : "-",
		chk_data, rd_count);

	if (rd_valid && rd_ready) begin
	       if (rd_data != chk_data) begin
			$display("%d: rd_data(%08x) != chk_data(%08x)",
				count, rd_data, chk_data);
			error_n = 1;
		end else begin
			rd_count_n = rd_count + 32'd1;
		end
	end

	case (count)
	32'd2: wr_valid_n = 1;
	32'd3: wr_valid_n = 0;
	32'd4: wr_valid_n = 1;
	32'd12: wr_valid_n = 0;
	32'd14: rd_ready_n = 1;
	32'd24: rd_ready_n = 0;
	32'd26: wr_valid_n = 1;
	32'd46: rd_ready_n = 1;
	32'd47: rd_ready_n = 0;
	32'd50: rd_ready_n = 1;
	32'd68: wr_valid_n = 0;
	32'd74: rd_ready_n = 0;
	32'd77: rd_ready_n = 1;
	32'd90: wr_valid_n = 1;
	32'd110: rd_ready_n = 0;
	32'd111: rd_ready_n = 1;
	32'd112: rd_ready_n = 0;
	32'd113: rd_ready_n = 1;
	32'd114: rd_ready_n = 0;
	32'd115: rd_ready_n = 0;
	32'd116: rd_ready_n = 1;
	32'd117: rd_ready_n = 1;
	32'd118: rd_ready_n = 0;
	32'd119: rd_ready_n = 0;
	32'd120: rd_ready_n = 0;
	32'd121: rd_ready_n = 1;
	32'd122: rd_ready_n = 1;
	32'd123: rd_ready_n = 1;
	32'd134: wr_valid_n = 0;
	32'd150: wr_valid_n = 1;
	32'd151: wr_valid_n = 0;
	32'd152: wr_valid_n = 1;
	32'd153: wr_valid_n = 1;
	32'd154: wr_valid_n = 0;
	32'd155: wr_valid_n = 0;
	32'd156: wr_valid_n = 0;
	32'd157: wr_valid_n = 1;
	32'd158: wr_valid_n = 1;
	32'd159: wr_valid_n = 1;
	32'd170: rd_ready_n = 0;
	32'd173: begin rd_ready_n = 1; wr_valid_n = 1; end
	32'd174: begin rd_ready_n = 0; wr_valid_n = 0; end
	32'd180: rd_ready_n = 1;
	32'd187: rd_ready_n = 0;
	32'd200: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd201: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd202: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd203: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd204: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd205: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd206: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd207: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd208: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd209: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd210: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd211: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd212: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd213: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd214: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd215: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd216: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd217: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd218: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd219: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd220: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd221: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd222: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd223: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd224: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd225: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd226: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd227: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd228: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd229: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd230: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd231: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd232: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd233: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd234: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd236: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd237: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd238: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd240: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd241: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd242: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd243: begin wr_valid_n = 0; rd_ready_n = 0; end
	32'd244: begin wr_valid_n = 1; rd_ready_n = 1; end
	32'd245: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd246: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd247: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd248: begin wr_valid_n = 1; rd_ready_n = 0; end
	32'd249: begin wr_valid_n = 0; rd_ready_n = 1; end
	32'd255: begin wr_valid_n = 1; rd_ready_n = 1; end

	32'd500: begin
		$display("did not read all data");
		error_n = 1;
	end
	default: ;
	endcase

	if (rd_count == 128) done_n = 1;
end

always_ff @(posedge clk) begin
	count <= count + 32'd1;
	rd_count <= rd_count_n;
	rd_ready <= rd_ready_n;
	wr_valid <= wr_valid_n;
	done = done_n;
	error = error_n;
end

sync_fifo #(
	.WIDTH(32),
	.DEPTH(4)
	) fifo (
	.clk(clk),
	.wr_data(wr_data),
	.wr_valid(wr_valid),
	.wr_ready(wr_ready),
	.rd_data(rd_data),
	.rd_valid(rd_valid),
	.rd_ready(rd_ready)
);

// write data stream
// cue up a new value next clock, whenever
// the current value would have been accepted
xorshift32 xs32wr (
	.clk(clk),
	.ready(wr_valid & wr_ready),
	.data(wr_data)
);

// read verification data stream
// cue up a new value next clock, whenever
// the current value would have been checked
xorshift32 xs32rd (
	.clk(clk),
	.ready(rd_valid & rd_ready),
	.data(chk_data)
);

endmodule
