// Copyright 2014, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module dvi_encoder(
	input wire clk,
	input wire active,
	input wire [7:0]din,
	input wire [1:0]ctrl,
	output reg [9:0]dout
	);

reg [3:0]acc = 0;

wire [8:0]xo;
wire [8:0]xn;

assign xn[0] = din[0];
assign xn[1] = din[1] ~^ xn[0];
assign xn[2] = din[2] ~^ xn[1];
assign xn[3] = din[3] ~^ xn[2];
assign xn[4] = din[4] ~^ xn[3];
assign xn[5] = din[5] ~^ xn[4];
assign xn[6] = din[6] ~^ xn[5];
assign xn[7] = din[7] ~^ xn[6];
assign xn[8] = 0;

assign xo[0] = din[0];
assign xo[1] = din[1] ^ xo[0];
assign xo[2] = din[2] ^ xo[1];
assign xo[3] = din[3] ^ xo[2];
assign xo[4] = din[4] ^ xo[3];
assign xo[5] = din[5] ^ xo[4];
assign xo[6] = din[6] ^ xo[5];
assign xo[7] = din[7] ^ xo[6];
assign xo[8] = 1;

localparam Z3 = 3'd0;

wire [3:0]ones =
	{Z3,din[0]} + {Z3,din[1]} + {Z3,din[2]} +
	{Z3,din[3]} + {Z3,din[4]} + {Z3,din[5]} +
	{Z3,din[6]} + {Z3,din[7]};

wire use_xn = ((ones > 4) | ((ones == 4) & (din[0] == 0)));

wire [8:0]tmp = use_xn ? xn : xo;
wire [3:0]tmp_ones =
	{Z3,tmp[0]} + {Z3,tmp[1]} + {Z3,tmp[2]} +
	{Z3,tmp[3]} + {Z3,tmp[4]} + {Z3,tmp[5]} +
	{Z3,tmp[6]} + {Z3,tmp[7]};

wire no_bias = (acc == 0) | (tmp_ones == 4);

wire same_sign = (acc[3] == tmp_ones[3]);

wire inv = no_bias ? (~tmp[8]) : same_sign;

wire [9:0]enc = { inv, tmp[8], inv ? ~tmp[7:0] : tmp[7:0] };
 
always @(posedge clk) begin
	if (active) begin
		dout <= enc;
		acc <= acc - 5 + {Z3,enc[0]} + {Z3,enc[1]} +
			{Z3,enc[2]} + {Z3,enc[3]} + {Z3,enc[4]} +
			{Z3,enc[5]} + {Z3,enc[6]} + {Z3,enc[7]} +
			{Z3,enc[8]} + {Z3,enc[9]};
	end else begin
		case (ctrl)
		2'b00: dout <= 10'b1101010100;
		2'b01: dout <= 10'b0010101011;
		2'b10: dout <= 10'b0101010100;
		2'b11: dout <= 10'b1010101011;
		endcase
		acc <= 0;
	end
end

endmodule
