// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

module cpu16_regs(
	input clk,
	input [2:0]asel,
	input [2:0]bsel,
	input [2:0]wsel,
	input wreg,
	input [15:0]wdata,
	output [15:0]adata,
	output [15:0]bdata
	);

`ifdef verilator
reg [15:0]rmem[0:7];
reg [15:0]areg;
reg [15:0]breg;

always_ff @(negedge clk) begin
	if (wreg)
		rmem[wsel] <= wdata;
end
always_ff @(posedge clk) begin
	areg <= rmem[asel];
	breg <= rmem[bsel];
end

assign adata = areg;
assign bdata = breg;
`else
`ifdef YOSYS
SB_RAM40_4K #(
        .READ_MODE(0),
        .WRITE_MODE(0)
        )
`else
SB_RAM256x16
`endif
        bank_a (
        .WADDR(wsel),
        .RADDR(asel),
        .MASK(16'b0),
        .WDATA(wdata),
        .RDATA(adata),
        .WE(1'b1),
        .WCLKE(wreg),
        .WCLK(clk),
        .RE(1'b1),
        .RCLKE(1'b1),
        .RCLK(clk)
        );

`ifdef YOSYS
SB_RAM40_4K #(
        .READ_MODE(0),
        .WRITE_MODE(0)
        )
`else
SB_RAM256x16
`endif
        bank_b (
        .WADDR(wsel),
        .RADDR(bsel),
        .MASK(16'b0),
        .WDATA(wdata),
        .RDATA(bdata),
        .WE(1'b1),
        .WCLKE(wreg),
        .WCLK(clk),
        .RE(1'b1),
        .RCLKE(1'b1),
        .RCLK(clk)
        );
`endif

endmodule


