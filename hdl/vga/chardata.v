// Copyright 2012, Brian Swetland
//
// Pixel Data Reader / Character Data Reader
//
// assert newline and provide line address to start linefetch
// character data will be provided on cdata two clocks later
//
// assert next to advance: character data will be provided two clocks later 
//
// vram_addr/vram_data: connect to sync sram

`timescale 1ns/1ns

module pixeldata(
	input clk,
	input newline,
	input advance,
	input [7:0] line,

	output [11:0] pixel,

	input [7:0] vram_data,
	output [10:0] vram_addr
	);

wire [7:0] new_cdata;
reg next;

chardata chardata(
	.clk(clk),
	.newline(newline),
	.line(line),
	.next(next),
	.cdata_o(new_cdata),
	.vram_data(vram_data),
	.vram_addr_o(vram_addr)
	);

reg [7:0] cdata, next_cdata;
reg [3:0] bitcount, next_bitcount;
reg [1:0] state = 2'h0, next_state;

always @(*) begin
	next_bitcount = bitcount;
	next_cdata = cdata;
	next = 1'b0;

	/* s0 machine is used to wait until the first cdata
	 * is ready after a newline signal, load that cdata,
	 * then enter the shift-out (s0=0) mode
	 */
	case (state)
	2'h3: next_state = 2'h2;
	2'h2: next_state = 2'h1;
	2'h1: begin
		next_state = 2'h0;
		next_cdata = new_cdata;
		end	
	2'h0: begin
		next_state = 2'h0;
		if (advance)
			next_bitcount = bitcount - 4'd1;
		if (bitcount == 4'h4)
			next = 1'b1;
		if (bitcount == 4'h0)
			next_cdata = new_cdata;
		end
	endcase

	if (newline) begin
		next_state = 2'h3;
		next_bitcount = 4'hF;
	end 

end

assign pixel = (cdata[bitcount[3:1]] ? 12'hFFF : 12'h00F);

always @(posedge clk) begin
	bitcount <= next_bitcount;
	state <= next_state;
	cdata <= next_cdata;
end

endmodule


module chardata(
	input clk,
	input newline,
	input next,
	input [7:0] line,
	output [7:0] cdata_o,

	input [7:0] vram_data,
	output [10:0] vram_addr_o
	);

`define SWAIT	2'h0
`define SLOAD	2'h1
`define SLATCH	2'h2

reg [7:0] pattern_rom [0:1023];
reg [2:0] pline, next_pline;

reg [1:0] state = `SWAIT, next_state;
reg [10:0] next_addr;
reg [7:0] next_cdata;

reg [7:0] cdata;
reg [10:0] vram_addr;

assign cdata_o = cdata;
assign vram_addr_o = vram_addr;

`ifdef HEX_PATHS
initial $readmemh("hdl/vga/prom.txt", pattern_rom);
`else
initial $readmemh("prom.txt", pattern_rom);
`endif

always_comb begin
	next_state = state;
	next_addr = vram_addr;
	next_cdata = cdata;
	next_pline = pline;
	if (newline) begin
		next_state = `SLOAD;
		next_addr = { line[7:3], 6'b0 };
		next_pline = line[2:0];
	end
`ifndef YOSYS
	else
`endif
	case (state)
	`SWAIT: if (next) begin	
		next_state = `SLOAD;
		end
	`SLOAD: begin
		next_state = `SLATCH;
		end
	`SLATCH: begin
		next_state = `SWAIT;
		next_addr = vram_addr + 11'd1;
		next_cdata = pattern_rom[{vram_data[6:0], pline}];
		end
	default: begin
		next_state = `SWAIT;
	end
	endcase
end

always_ff @(posedge clk) begin
	state <= next_state;	
	vram_addr <= next_addr;
	cdata <= next_cdata;
	pline <= next_pline;
end

endmodule 
