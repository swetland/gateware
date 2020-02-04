// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module sdram_glue #(
	parameter AWIDTH = 12,
	parameter DWIDTH = 16
	) (
	input wire clk,
	output wire pin_clk,
	output wire pin_ras_n,
	output wire pin_cas_n,
	output wire pin_we_n,
	output wire [AWIDTH-1:0]pin_addr,
	inout wire [DWIDTH-1:0]pin_data,
	input wire ras_n,
	input wire cas_n,
	input wire we_n,
	input wire [AWIDTH-1:0]addr,
	input wire [DWIDTH-1:0]data_i,
	output wire [DWIDTH-1:0]data_o,
	output wire data_oe
);

assign pin_ras_n = ras_n;
assign pin_cas_n = cas_n;
assign pin_we_n = we_n;
assign pin_addr = addr;

ODDRX1F clock_ddr (
        .Q(pin_clk),
        .SCLK(clk),
        .RST(0),
        .D0(1),
        .D1(0)
);

genvar n;
generate
for (n = 0; n < DWIDTH; n++) begin
	BB iobuf (
		.I(data_o[n]),
		.T(~data_oe),
		.O(data_i[n]),
		.B(pin_data[n])
	);
end
endgenerate

endmodule
	
