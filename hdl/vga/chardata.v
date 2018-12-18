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

`default_nettype none

`timescale 1ns/1ns

module pixeldata #(
	parameter BPP = 2
)(
	input clk,
	input newline,
	input advance,
	input [7:0] line,
	output [(3*BPP)-1:0] pixel,
	input [7:0] vram_data,
	output [10:0] vram_addr
);

wire [(3*BPP)-1:0]FG = { 3*BPP { 1'b1 }};
wire [(3*BPP)-1:0]BG = { { 2*BPP { 1'b0 }}, { BPP { 1'b1 }} };

reg [7:0] pattern_rom [0:1023];

`ifdef HEX_PATHS
initial $readmemh("hdl/vga/prom.txt", pattern_rom);
`else
initial $readmemh("prom.txt", pattern_rom);
`endif

reg next_load;
reg next_load_cdata;
reg next_loaded_cdata;
reg next_load_pdata;
reg next_load_pattern;
reg [5:0] next_xpos;
reg [3:0] next_ppos;
reg [15:0] next_pattern;

reg load = 1'b0;
reg load_cdata = 1'b0;
reg loaded_cdata = 1'b0;
reg load_pdata = 1'b0;
reg load_pattern = 1'b0;
reg [5:0]xpos = 6'b0;
reg [3:0]ppos = 4'b0;
reg [15:0]pattern = 16'b0;

reg [7:0]cdata;
reg [7:0]pdata;

// generate vram address by using the high bits of the display
// line and the local xpos character counter
assign vram_addr = { line[7:3], xpos };

// generate pattern rom address by using the character id
// fetched from vram as the high bits and the low bits of
// the display line to further index into the correct pattern
wire [9:0] prom_addr = { cdata[6:0], line[2:0] };

`ifdef ASYNC_ROM
wire [7:0] prom_data = pattern_rom[prom_addr];
`else
reg [7:0] prom_data;
always_ff @(posedge clk)
	prom_data <= pattern_rom[prom_addr];
`endif

// double-wide pattern data
wire [15:0]pdata2x = {
	pdata[7], pdata[7], pdata[6], pdata[6],
	pdata[5], pdata[5], pdata[4], pdata[4],
	pdata[3], pdata[3], pdata[2], pdata[2],
	pdata[1], pdata[1], pdata[0], pdata[0]
	};

// the high bit of the pattern shift register is used to
// select the FG or BG color and feed out to the vga core
assign pixel = pattern[15] ? FG : BG;

always_comb begin
	next_xpos = xpos;
	next_ppos = ppos;
	next_pattern = pattern;
	next_load = 1'b0;

	// multi-step load (cdata, then pdata, then pattern)
	next_load_cdata = load;
	next_loaded_cdata = load_cdata;
	next_load_pdata = loaded_cdata;
	next_load_pattern = load_pdata;
	
	if (newline) begin
		// reset character counter (xpos), pattern counter (ppos),
		// and preload the first pattern
		next_load = 1'b1;
		next_xpos = 6'b0;
		next_ppos = 4'b0;
	end else if (advance) begin
		next_ppos = ppos + 4'h1;
		if (ppos == 4'hF) begin
			// advance to next pattern (preloaded in pdata)
			next_pattern = pdata2x;
		end else begin
			// advance to the next bit in the current pattern
			next_pattern = { pattern[14:0], 1'b0 };
			if (ppos == 4'd0) begin
				// advance xpos and start preloading
				// for the next character
				next_load = 1'b1;
				next_xpos = xpos + 6'd1;
			end
		end
	end else begin
		// handle the final step of preloading the pattern
		// for xpos 0 (between newline=1 and advance=1)
		if (load_pattern)
			next_pattern = pdata2x;
	end
end

always_ff @(posedge clk) begin
	load <= next_load;
	load_cdata <= next_load_cdata;
	loaded_cdata <= next_loaded_cdata;
	load_pdata <= next_load_pdata;
	load_pattern <= next_load_pattern;
	xpos <= next_xpos;
	ppos <= next_ppos;
	pattern <= next_pattern;
	if (load_cdata)
		cdata <= vram_data;
	if (load_pdata)
		pdata <= prom_data;
end

endmodule
