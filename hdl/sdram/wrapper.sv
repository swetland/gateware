
`default_nettype none

module top(
	input wire clk,
	input wire a,
	input wire b,
	input wire c,
	output wire d
);

wire reset;
wire sdram_clk;
wire sdram_ras_n;
wire sdram_cas_n;
wire sdram_we_n;
wire [15:0]sdram_data_i;
wire [15:0]sdram_data_o;
wire [11:0]sdram_addr;
wire [19:0]rd_addr;
wire [3:0]rd_len;
wire rd_req;
wire rd_ack;
wire [15:0]rd_data;
wire rd_rdy;
wire [19:0]wr_addr;
wire [15:0]wr_data;
wire [3:0]wr_len;
wire wr_req;
wire wr_ack;

sdram sdram0(
	.clk(clk),
	.reset(reset),
	.pin_clk(sdram_clk),
	.pin_ras_n(sdram_ras_n),
	.pin_cas_n(sdram_cas_n),
	.pin_we_n(sdram_we_n),
	.pin_data_i(sdram_data_i),
	.pin_data_o(sdram_data_o),
	.pin_addr(sdram_addr),
	.rd_addr(rd_addr),
	.rd_len(rd_len),
	.rd_req(rd_req),
	.rd_ack(rd_ack),
	.rd_data(rd_data),
	.rd_rdy(rd_rdy),
	.wr_addr(wr_addr),
	.wr_data(wr_data),
	.wr_len(wr_len),
	.wr_req(wr_req),
	.wr_ack(wr_ack)
);

synth_input_wrapper #(
	.WIDTH(83)
	) wrap_input (
	.clk(clk),
	.pin_in(a),
	.pin_valid(b),
	.din({ reset, sdram_data_i, rd_addr, rd_len, rd_req,
		wr_addr, wr_data, wr_len, wr_req })
);

synth_output_wrapper #(
	.WIDTH(51)
	) wrap_output (
	.clk(clk),
	.dout( { sdram_clk, sdram_ras_n, sdram_cas_n, sdram_we_n,
		sdram_data_o, sdram_addr, rd_ack, rd_data, rd_rdy, wr_ack }),
	.pin_capture(c),
	.pin_out(d)
);

endmodule
