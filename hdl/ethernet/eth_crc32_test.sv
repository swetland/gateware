// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module testbench(
	input clk,
	output reg error = 0,
	output reg done = 0
);

reg [8:0]packet[0:103];

initial $readmemh("hdl/ethernet/eth_crc32_testpacket.hex", packet);

reg [6:0]pktcount = 7'd0;
reg rst = 1'b1;
reg wr = 1'b0;
reg [7:0]pktdata = 8'd0;
reg pktdone = 1'b0;
wire [31:0]crc0;
wire [31:0]crc1;

`ifdef BYTEWISE
eth_crc32_8(
	.clk(clk),
	.en(wr & ~pktdone),
	.rst(rst),
	.din(pktdata),
	.crc(crc0)
);

always_ff @(posedge clk) begin
	rst <= 1'b0;
	wr <= 1'b1;
	if (~pktdone)
		{ pktdone, pktdata } <= packet[pktcount];
	pktcount <= pktcount + 7'd1;
	$display("WR=", wr, " DONE=", pktdone, " IDX=", pktcount, " DATA=", pktdata, " CRC=", crc0, " NOT=", ~crc0);
	if (pktdone) begin
		if(crc0 == 32'hdebb20e3) begin
			$display("SUCCESS");
			done <= 1;
		end else begin
			$display("FAILURE");
			error <= 1;
		end
		done <= 1;
	end
	if (pktcount == 105) error <= 1;
end
`else
reg [3:0]tick = 4'b0001;

eth_crc32_2 ethcrc0(
	.clk(clk),
	.en(wr & ~pktdone),
	.rst(rst),
	.din(pktdata[1:0]),
	.crc(crc0)
);

eth_crc32_8 ethcrc1(
	.clk(clk),
	.en(tick[3] & ~pktdone),
	.rst(rst),
	.din(pktdata),
	.crc(crc1)
);

always_ff @(posedge clk) begin
	rst <= 1'b0;
	wr <= 1'b1;
	if (~pktdone) begin
		if (tick[0]) begin
			{ pktdone, pktdata } <= packet[pktcount];
			pktcount <= pktcount + 7'd1;
		end else begin
			{ pktdone, pktdata } <= { pktdone, 2'b0, pktdata[7:2] };
		end
		tick <= { tick[0], tick[3:1] };
	end
	$display("WR=", wr, " DONE=", pktdone, " IDX=", pktcount, " DATA=", pktdata, " CRCx2=", crc0, " CRCx8=", crc1, " NOT=", ~crc1);
	if (pktdone) begin
		if (crc0 != 32'hdebb20e3) begin
			$display("CRC32x2 FAILED");
			error <= 1;
		end else if (crc1 != 32'hdebb20e3) begin
			$display("CRC32x8 FAILED");
			error <= 1;
		end else begin
			$display("SUCCESS");
			done <= 1;
		end
	end
	if (pktcount == 105) error <= 1;
end
`endif

endmodule
