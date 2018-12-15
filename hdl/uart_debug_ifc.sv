// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module uart_debug_ifc(
	input sys_clk,
	output sys_wr,
	output [15:0]sys_waddr,
	output [15:0]sys_wdata,
	input uart_rx,
	output uart_tx,
	output led_red,
	output led_grn
);

reg crc_rst = 1'b0;
reg crc_rst_next;

wire crc_din;
wire crc_en;
wire [7:0]crc;

wire [7:0]rxdata;
wire rxready;

uart_rx rx_uart(
	.clk(sys_clk),
	.rx(uart_rx),
	.data(rxdata),
	.ready(rxready),
	.crc_din(crc_din),
	.crc_en(crc_en)
	);

crc8_serial rx_crc(
	.clk(sys_clk),
	.din(crc_din),
	.en(crc_en),
	.rst(crc_rst),
	.crc(crc)
	);

reg wr = 1'b0;
reg wr_next;

reg [31:0]addr = 32'd0;
reg [31:0]data = 32'd0;
reg [7:0]cmd = 8'd0;

reg [7:0]cmd_next;
reg [7:0]dat0_next;
reg [7:0]dat1_next;
reg [7:0]dat2_next;
reg [7:0]dat3_next;
reg [31:0]addr_next;

localparam SINIT = 3'd0;
localparam SCMD = 3'd1;
localparam SDAT0 = 3'd2;
localparam SDAT1 = 3'd3;
localparam SDAT2 = 3'd4;
localparam SDAT3 = 3'd5;
localparam SCRC = 3'd6;
localparam SIDLE = 3'd7;

reg [2:0]state = SINIT;
reg [2:0]state_next; 

reg error = 1'b0;
reg error_next;

always_comb begin
	state_next = state;
	wr_next = 1'b0;
	crc_rst_next = 1'b0;
	cmd_next = cmd;
	dat0_next = data[7:0];
	dat1_next = data[15:8];
	dat2_next = data[23:16];
	dat3_next = data[31:24];
	addr_next = addr;
	error_next = error;

	case (state)
	SINIT: begin
		state_next = SIDLE;
		crc_rst_next = 1'b1;
	end
	SIDLE: begin
		if (rxready) begin
			if (rxdata == 8'hCD) begin
				state_next = SCMD;
			end else begin
				error_next = 1'b1;
				crc_rst_next = 1'b1;
			end
		end
	end
	SCMD: begin
		if (rxready) begin
			state_next = SDAT0;
			cmd_next = rxdata;
		end
	end
	SDAT0: begin
		if (rxready) begin
			state_next = SDAT1;
			dat0_next = rxdata;
		end
	end
	SDAT1: begin
		if (rxready) begin
			state_next = SDAT2;
			dat1_next = rxdata;
		end
	end
	SDAT2: begin
		if (rxready) begin
			state_next = SDAT3;
			dat2_next = rxdata;
		end
	end
	SDAT3: begin
		if (rxready) begin
			state_next = SCRC;
			dat3_next = rxdata;
		end
	end
	SCRC: begin
		if (rxready) begin
			state_next = SIDLE;
			crc_rst_next = 1'b1;
			if (crc == 8'd0) begin
				case (cmd)
				8'h00: wr_next = 1'b1;
				8'h01: addr_next = data;
				8'h02: error_next = 1'b0;
				default: error_next = 1'b1;
				endcase
			end else begin
				error_next = 1'b1;
			end
		end
	end
	endcase
end

always_ff @(posedge sys_clk) begin
	state <= state_next;
	cmd <= cmd_next;
	addr <= wr ? (addr + 32'd1) : addr_next;
	data <= { dat3_next, dat2_next, dat1_next, dat0_next };
	crc_rst <= crc_rst_next;
	wr <= wr_next;
	error <= error_next;
end

assign sys_wr = wr;
assign sys_waddr = addr[15:0];
assign sys_wdata = data[15:0];

assign led_grn = ~(crc == 8'd0);
assign led_red = ~error;

assign uart_tx = uart_rx;

endmodule
