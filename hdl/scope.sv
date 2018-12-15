// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

// Captures up to 16K samples of 64 bits while trace_en
// Plays them back over the uart when ~trace_en

module scope(
	input clk,
	input [63:0]trace_in,
	input trace_en,
	output uart_tx
	);

wire [63:0]trace_out;

reg [13:0]trace_waddr = 14'd0;
reg [13:0]trace_waddr_next;
wire [13:0]trace_waddr_incr;
wire trace_wdone;

assign { trace_wdone, trace_waddr_incr } = { 1'b0, trace_waddr } + 15'd1;

always_comb begin
	trace_waddr_next = trace_waddr;
	if (trace_en) begin
		if (~trace_wdone)
			trace_waddr_next = trace_waddr_incr;
	end else begin
		trace_waddr_next = 14'd0;
	end
end

always_ff @(posedge clk) begin
	trace_waddr <= trace_waddr_next;
end

reg [16:0]trace_raddr = 17'd0;
reg [16:0]trace_raddr_next;
wire [16:0]trace_raddr_incr;
wire trace_rdone;

assign { trace_rdone, trace_raddr_incr } = { 1'b0, trace_raddr[16:0] } + 18'd1;

reg [7:0]trace_byte;

always_comb begin
	case (trace_raddr[2:0])
	3'd0: trace_byte = trace_out[7:0];
	3'd1: trace_byte = trace_out[15:8];
	3'd2: trace_byte = trace_out[23:16];
	3'd3: trace_byte = trace_out[31:24];
	3'd4: trace_byte = trace_out[39:32];
	3'd5: trace_byte = trace_out[47:40];
	3'd6: trace_byte = trace_out[55:48];
	3'd7: trace_byte = trace_out[63:56];
	endcase
end

reg [4:0]clkcount_next;
reg [4:0]bitcount_next;
reg [12:0]shift_next;
reg reload_next;

reg [4:0]clkcount = 5'd0;
reg [4:0]bitcount = 5'd0; // IDLE(1) STOP(1) DATA(x) x 8 START(0) -> wire
reg [12:0]shift = 13'd0;
reg reload = 1'b0;

always_comb begin
	shift_next = shift;
	clkcount_next = clkcount;
	bitcount_next = bitcount;
	trace_raddr_next = trace_raddr;
	reload_next = 1'b0;

	if (trace_en) begin
		shift_next = 13'h1FFF;
		clkcount_next = 5'd10;
		bitcount_next = 5'd12;
		trace_raddr_next = 17'd0;
	end else begin
		if (reload) begin
			shift_next = { 4'b1111, trace_byte, 1'b0 };
		end
		if (clkcount[4] & (~trace_rdone)) begin
			// underflow! one uart bit time has passed
			clkcount_next = 5'd10;
			if (bitcount[4]) begin
			 	// undeflow! one uart character has been sent
				// bump the read addr, but defer reload to
				// next cycle
				trace_raddr_next = trace_raddr_incr;
				shift_next = { 4'b1111, trace_byte, 1'b0 };
				reload_next = 1'b1;
				bitcount_next = 5'd12;
			end else begin
				shift_next = { 1'b1, shift[12:1] };
				bitcount_next = bitcount - 5'd1;
			end
		end else begin
			clkcount_next = clkcount - 5'd1;
		end
	end
end

always_ff @(posedge clk) begin
	shift <= shift_next;
	clkcount <= clkcount_next;
	bitcount <= bitcount_next;
	trace_raddr <= trace_raddr_next;
end

assign uart_tx = shift[0];

wire trace_we = trace_en;
wire [13:0]trace_addr = trace_we ? trace_waddr : trace_raddr[16:3];

spram tram0(
	.clk(clk),
	.addr(trace_addr),
	.wr_data(trace_in[63:48]),
	.rd_data(trace_out[63:48]),
	.wr_en(trace_we)
	);
spram tram1(
	.clk(clk),
	.addr(trace_addr),
	.wr_data(trace_in[47:32]),
	.rd_data(trace_out[47:32]),
	.wr_en(trace_we)
	);
spram tram2(
	.clk(clk),
	.addr(trace_addr),
	.wr_data(trace_in[31:16]),
	.rd_data(trace_out[31:16]),
	.wr_en(trace_we)
	);
spram tram3(
	.clk(clk),
	.addr(trace_addr),
	.wr_data(trace_in[15:0]),
	.rd_data(trace_out[15:0]),
	.wr_en(trace_we)
	);

endmodule



module spram(
	input clk,
	input [13:0]addr,
	input [15:0]wr_data,
	output [15:0]rd_data,
	input wr_en
	);

`ifdef verilator
reg [15:0]mem[0:16383];
reg [15:0]data;

always_ff @(posedge clk) begin
	if (wr_en)
		mem[addr] <= wr_data;
	else
		data <= mem[addr];
end

assign rd_data = data;
`else
SB_SPRAM256KA spram_inst(
	.ADDRESS(addr),
	.DATAIN(wr_data),
	.DATAOUT(rd_data),
	.MASKWREN(4'b1111),
	.WREN(wr_en),
	.CHIPSELECT(1'b1),
	.CLOCK(clk),
	.STANDBY(1'b0),
	.SLEEP(1'b0),
	.POWEROFF(1'b1) // active low
	);
`endif

endmodule


