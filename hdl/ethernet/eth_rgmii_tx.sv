// Copyright 2020 Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module eth_rgmii_tx (
	input wire tx_clk,

	output wire pin_tx_clk,
	output wire pin_tx_en,
	output wire [3:0]pin_tx_data,

	// strobe to request start
	// data will be accepted 8-20 clocks later
	// (depending on how soon after last packet finished)
	input wire start,

	// asserted to accept a byte	
	output reg ready = 0,

	// assert when a byte is ready to transmit
	// once data transmission begins, deassertion will end the packet
	input wire valid,

	// assert to cease transmitting and ensure packet is invalid
	// (do not complete FCS computation)
	input wire error,

	// byte to transmit
	input wire [7:0]data
);

localparam IDLE = 3'd0;
localparam PREAMBLE = 3'd1;
localparam PACKET = 3'd2;
localparam CRC1 = 3'd3;
localparam CRC2 = 3'd4;
localparam CRC3 = 3'd5;
localparam CRC4 = 3'd6;
localparam WAIT = 3'd7;

reg [2:0]state = IDLE;
reg tx_en = 0;
reg tx_err = 0;
reg [7:0]tx_data = 8'd0;
reg [3:0]count = 4'd0;

reg [2:0]next_state;
reg [3:0]next_count;
reg next_tx_en;
reg next_tx_err;
reg [7:0]next_tx_data;
reg next_ready;

wire [3:0]count_sub1;
wire count_done;
assign { count_done, count_sub1 } = { 1'b0, count } - 5'd1;

reg crc_en;
wire [31:0]crc;

always_comb begin
	next_state = state;
	next_count = count;
	next_tx_data = tx_data;
	next_tx_en = tx_en;
	next_tx_err = tx_err;
	next_ready = 1'b0;

	case (state)
	IDLE: if (start) begin
		next_state = PREAMBLE;
		next_count = 4'd6;
		next_tx_data = 8'h55;
		next_tx_en = 1'b1;
	end
	PREAMBLE: if (count_done) begin
		next_state = PACKET;
		next_tx_data = 8'hD5;
		next_ready = 1'b1;
		next_count = 4'd11; // preload IPG count
	end else begin
		next_count = count_sub1;
	end
	PACKET: if (valid) begin
		next_ready = 1'b1;
		next_tx_data = data;
	end else begin
		next_state = CRC1;
		next_tx_data = ~crc[7:0];
	end
	CRC1: begin
		next_state = CRC2;
		next_tx_data = ~crc[15:8];
	end
	CRC2: begin
		next_state = CRC3;
		next_tx_data = ~crc[23:16];
	end
	CRC3: begin
		next_state = CRC4;
		next_tx_data = ~crc[31:24];
	end
	CRC4: begin
		next_state = WAIT;
		next_tx_data = 8'd0;
		next_tx_en = 1'b0;
	end
	WAIT: if (count_done) begin
		next_state = IDLE;
	end else begin
		next_count = count_sub1;
	end
	default: next_state = IDLE;
	endcase
end

always_ff @(posedge tx_clk) begin
	state <= next_state;
	count <= next_count;
	tx_data <= next_tx_data;
	tx_en <= next_tx_en;
	tx_err <= next_tx_err;
	ready <= next_ready;
end

// hardware-specific io buffers, delats, etc
eth_rgmii_tx_glue glue(
	.tx_clk(tx_clk),
	.pin_tx_clk(pin_tx_clk),
	.pin_tx_en(pin_tx_en),
	.pin_tx_data(pin_tx_data),
	.tx_en(tx_en),
	.tx_err(tx_err),
	.tx_data(tx_data)
);

eth_crc32_8 crc32(
	.clk(tx_clk),
	.en(valid & ready),
	.rst(start),
	.din(data),
	.crc(crc)
);
endmodule
