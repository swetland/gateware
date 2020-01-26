`default_nettype none

module top(
	input wire phy_clk,
	output wire phy_reset_n,

	input wire phy0_rxc,
	input wire [3:0]phy0_rxd,
	input wire phy0_rx_dv,

	output wire phy1_gtxclk,
	output wire phy1_tx_en,
	output wire [3:0]phy1_txd,

	output wire glb_clk,
	output wire glb_bln,
	output wire j1r0,
	output wire j1r1,
	output wire j1g0,
	output wire j1g1,
	output wire j1b0,
	output wire j1b1,
	output wire glb_a,
	output wire glb_b,
	input wire btn
);

wire clk25m = phy_clk;

wire clk125m;
wire clk250m;

pll_25_125_250 pll(
	.clk25m_in(phy_clk),
	.clk125m_out(clk125m),
	.clk250m_out(clk250m),
	.locked()
);

`ifdef XXX
reg [31:0]count1;
always_ff @(posedge phy1_rxc) begin
	count1 <= count1 + 32'd1;
end
assign glb_clk = count1[1];

reg [31:0]count0;
always_ff @(posedge phy0_rxc) begin
	count0 <= count0 + 32'd1;
end
assign glb_bln = count0[1];
`endif

wire tx_clk = clk125m;
reg tx_start = 0;
reg tx_valid = 0;
reg tx_error = 0;
reg [7:0]tx_data = 8'd0;
wire tx_ready;

eth_rgmii_tx eth_tx(
	.tx_clk(tx_clk),
	.pin_tx_clk(phy1_gtxclk),
	.pin_tx_en(phy1_tx_en),
	.pin_tx_data(phy1_txd),
	.start(tx_start),
	.ready(tx_ready),
	.valid(tx_valid),
	.error(tx_error),
	.data(tx_data)
);


reg [7:0]msgram[0:63];

initial $readmemh("hdl/message.hex", msgram);


reg [31:0]count1s = 32'd0;
always_ff @(posedge tx_clk) begin
	if (count1s == 32'd125000000) begin
		count1s <= 32'd0;
		tx_start <= 1;
	end else begin
		count1s <= count1s + 32'd1;
		tx_start <= 0;
	end
end

reg [7:0]xcount = 8'd0;
reg [7:0]next_xcount;
reg next_tx_valid;
reg [7:0]next_tx_data;

always_comb begin
	next_xcount = xcount;
	next_tx_valid = tx_valid;
	next_tx_data = xcount;

	if (tx_start) begin
		next_tx_valid = 1;
		next_xcount = 8'd0;
	end

	if (tx_valid & tx_ready) begin
		if (xcount < 8'd64) begin
			next_xcount = xcount + 8'd1;
		end else begin
			next_tx_valid = 0;
		end
	end
end

always_ff @(posedge tx_clk) begin
	xcount <= next_xcount;
	tx_valid <= next_tx_valid;
	tx_data <= msgram[next_xcount[5:0]];
end

wire [7:0]rx_data;
wire rx_valid;
wire rx_sop;
wire rx_eop;
wire rx_crc_ok;

eth_rgmii_rx eth_rx(
	.rx_clk(phy0_rxc),
	.pin_rx_dv(phy0_rx_dv),
	.pin_rx_data(phy0_rxd),
	.data(rx_data),
	.valid(rx_valid),
	.sop(rx_sop),
	.eop(rx_eop),
	.crc_ok(rx_crc_ok)
);

assign j1r1 = j1r0;
assign j1b1 = j1b0;
assign j1g1 = j1g0;

reg [31:0]reset = 32'd0;
always @(posedge clk25m)
	reset <= { reset[30:0], 1'b1 };

assign phy_reset_n = reset[31];

reg [11:0]waddr = 12'd0;

reg [27:0]color = 28'h1234567;

always_ff @(posedge phy0_rxc) begin
	color <= rx_eop ? { color[23:0], color[27:24] } : color;
	waddr <= (rx_eop | rx_valid)  ? (waddr + 12'd2) : waddr;
end

wire [15:0]mark = rx_crc_ok ? { 16'h0200 } : { 16'h04FF };

display #(
        .BPP(1),
        .RGB(1),
        .WIDE(0),
	.HEXMODE(1)
        ) display0 (
        .clk(clk25m),
        .red(j1r0),
        .grn(j1g0),
        .blu(j1b0),
        .hsync(glb_a),
        .vsync(glb_b),
        .active(),
        .frame(),
        .wclk(phy0_rxc),
        .waddr(waddr),
        .wdata(rx_eop ? mark : { color[27:24], 4'h0, rx_data }),
        .we((rx_eop | rx_valid) & btn)
);

endmodule

