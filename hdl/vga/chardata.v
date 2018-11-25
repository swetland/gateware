// Copyright 2018, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.
//
// Character Display Engine
//
// newline strobes on the first pixel of a new line
// advance strobes on each visible pixel of a new line
// line provides the visible line count 0..239
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

reg [7:0] pattern_rom [0:1023];

`ifdef HEX_PATHS
initial $readmemh("hdl/vga/prom.txt", pattern_rom);
`else
initial $readmemh("prom.txt", pattern_rom);
`endif

reg next_load;
reg [5:0] next_xpos;
reg [3:0] next_ppos;
reg [15:0] next_pattern;

reg load = 1'b0;
reg [5:0] xpos = 6'b0;
reg [3:0] ppos = 4'b0;
reg [15:0] pattern = 16'b0;

// generate vram address by using the high bits of the display
// line and the local xpos character counter
assign vram_addr = { line[7:3], next_xpos };

// generate pattern rom address by using the character id
// fetched from vram as the high bits and the low bits of
// the display line to further index into the correct pattern
wire [9:0] pattern_addr = { vram_data[6:0], line[2:0] };

`ifdef ASYNC_ROM
wire [7:0] cdata = pattern_rom[pattern_addr];
`else
reg [7:0] cdata;
always_ff @(posedge clk)
	cdata <= pattern_rom[pattern_addr];
`endif


// the high bit of the pattern shift register is used to
// select the FG or BG color and feed out to the vga core
assign pixel = pattern[15] ? 12'hFFF : 12'h00F;

always_comb begin
	next_xpos = xpos;
	next_ppos = ppos;
	next_pattern = pattern;
	next_load = 1'b0;

	if (newline) begin
		next_load = 1'b1;
		next_xpos = 6'b0;
		next_ppos = 4'b0;
	end else if (advance) begin
		next_ppos = ppos + 4'h1;
		if (ppos == 4'hF) begin
			next_load = 1'b1;
			next_xpos = xpos + 6'b1;
		end
	end

	// pattern shift register
	if (load) begin
		// 8bit wide character pattern line is expanded 
		// into the 16bit pattern shift register
		next_pattern = {
			cdata[7], cdata[7], cdata[6], cdata[6],
			cdata[5], cdata[5], cdata[4], cdata[4],
			cdata[3], cdata[3], cdata[2], cdata[2],
			cdata[1], cdata[1], cdata[0], cdata[0]
			};
	end else if (advance) begin
		next_pattern = { pattern[14:0], 1'b0 };
	end

end

always_ff @(posedge clk) begin
	load <= next_load;
	xpos <= next_xpos;
	ppos <= next_ppos;
	pattern <= next_pattern;
end

endmodule
