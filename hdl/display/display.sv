// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.

`default_nettype none

module display #(
	parameter BPP = 2,

	// WIDE=0 selects 80x30, 2.5KB VRAM
	// WIDE=1 selects 40x30, 1.5KB VRAM
	parameter WIDE = 1,

	// MINIFONT=0 selects half-ascii (0 through 127) 4KB PROM
	// MINIFONT=1 selects quarter-ascii (uppercase only) 2KB PROM
	// (0..31 map to 32..63, 96..127 map to 64..95)
	parameter MINIFONT = 0,

	// horizontal timing (all values -1)
	parameter HZNT_FRONT = 15,
	parameter HZNT_SYNC = 95,
	parameter HZNT_BACK = 47,
	parameter HZNT_ACTIVE = 639,

	// vertical timing (all values -1)
	parameter VERT_FRONT = 11,
	parameter VERT_SYNC = 1,
	parameter VERT_BACK = 29,
	parameter VERT_ACTIVE = 479
	)(
	input wire clk,

	output wire [BPP-1:0]red,
	output wire [BPP-1:0]grn,
	output wire [BPP-1:0]blu,
	output wire hsync,
	output wire vsync,
	output wire active,
	output wire frame,

	input wire wclk,
	input wire [11:0]waddr,
	input wire [7:0]wdata,
	input wire we
);

localparam PWIDTH = WIDE ? 16 : 8;
localparam PCOUNT = WIDE ? 15 : 7;
localparam VRAMSZ = WIDE ? 1536 : 2560;
localparam VRAMAW = WIDE ? 11 : 12;

localparam PROMSZ = MINIFONT ? 1024 : 2048;
localparam PROMAW = MINIFONT ? 10 : 11;

wire hs;
wire vs;
wire start_frame;
wire start_line;
wire pxl_accept;
wire [9:0]pxl_x;
wire [9:0]pxl_y;

assign hsync = hs;
assign vsync = vs;
assign active = pxl_accept;
assign frame = start_frame;

display_timing #(
	.HZNT_FRONT(HZNT_FRONT),
	.HZNT_SYNC(HZNT_SYNC),
	.HZNT_BACK(HZNT_BACK),
	.HZNT_ACTIVE(HZNT_ACTIVE),
	.VERT_FRONT(VERT_FRONT),
	.VERT_SYNC(VERT_SYNC),
	.VERT_BACK(VERT_BACK),
	.VERT_ACTIVE(VERT_ACTIVE)
	) timing (
	.clk(clk),
	.hsync(hs),
	.vsync(vs),
	.start_frame(start_frame),
	.start_line(start_line),
	.pxl_accept(pxl_accept),
	.pxl_x(pxl_x),
	.pxl_y(pxl_y)
);

// VIDEO RAM
//
reg [7:0] video_ram[0:VRAMSZ-1];

`ifdef HEX_PATHS
initial $readmemh("hdl/display/vram-40x30.hex", video_ram);
`else
initial $readmemh("vram-40x30.hex", video_ram);
`endif

wire re;
wire [11:0] raddr;
reg [7:0] vdata;

always_ff @(posedge wclk) begin
	if (we)
		video_ram[waddr[VRAMAW-1:0]] <= wdata;
end

always_ff @(posedge clk) begin
	if (re)
		vdata <= video_ram[raddr[VRAMAW-1:0]];
end

// PATTERN ROM
//
reg [7:0] pattern_rom [0:PROMSZ-1];

`ifdef HEX_PATHS
generate
if (MINIFONT) initial $readmemh("hdl/display/fontdata-8x16x64.hex", pattern_rom);
else initial $readmemh("hdl/display/fontdata-8x16x128.hex", pattern_rom);
endgenerate
`else
generate
if (MINIFONT) initial $readmemh("fontdata-8x16x64.hex", pattern_rom);
else initial $readmemh("fontdata-8x16x128.hex", pattern_rom);
endgenerate
`endif

wire [PROMAW-1:0] prom_addr;

// generate pattern rom address based on character id
// from vram and the low bits of the display line
generate
if (MINIFONT) assign prom_addr = { vdata[6], vdata[4:0], pxl_y[3:0] };
else assign prom_addr = { vdata[6:0], pxl_y[3:0] };
endgenerate

reg [7:0]prom_data;

always_ff @(posedge clk) begin
	prom_data <= pattern_rom[prom_addr];
end

reg [PWIDTH-1:0]pattern;
reg [PWIDTH-1:0]pattern_next;
reg [3:0]pattern_count;
reg [3:0]pattern_count_next;
reg [3:0]pattern_count_sub1;
reg pattern_count_done;

assign { pattern_count_done, pattern_count_sub1 } = { 1'b0, pattern_count } - 5'd1;

reg load_character_addr = 1'b0;
reg load_character_addr_next;

reg [11:0]vram_raddr;
reg [11:0]vram_raddr_next;

wire [11:0]vram_raddr_add1 = vram_raddr + 12'd1;

assign raddr = vram_raddr;
assign re = load_character_addr;

reg [PWIDTH-1:0]pattern_expand;
generate
	if (WIDE) assign pattern_expand = {
		prom_data[7], prom_data[7], prom_data[6], prom_data[6],
		prom_data[5], prom_data[5], prom_data[4], prom_data[4],
		prom_data[3], prom_data[3], prom_data[2], prom_data[2],
		prom_data[1], prom_data[1], prom_data[0], prom_data[0] };
	else assign pattern_expand = prom_data;
endgenerate

reg preload1 = 1'b0;
reg preload1_next;
reg preload2 = 1'b0;
reg preload2_next;
reg preload3 = 1'b0;
reg preload3_next;

// high bits of y position x40 or x80
wire [11:0]vram_rowbase;
generate
if (WIDE) assign vram_rowbase = { 3'b0, pxl_y[9:4], 3'b0 } + { pxl_y[9:4], 5'b0 };
else assign vram_rowbase = { 2'b0, pxl_y[9:4], 4'b0 } + { pxl_y[9:4], 6'b0 };
endgenerate

always_comb begin
	vram_raddr_next = vram_raddr;
	load_character_addr_next = 1'b0;
	pattern_next = pattern;
	pattern_count_next = pattern_count;
	preload1_next = 1'b0;
	preload2_next = preload1;
	preload3_next = preload2;

	if (pxl_accept) begin
		if (pattern_count_done) begin
			pattern_next = pattern_expand;
			pattern_count_next = PCOUNT;
			load_character_addr_next = 1'b1;
			vram_raddr_next = vram_raddr_add1;
		end else begin
			pattern_next = { pattern[PWIDTH-2:0], 1'b0 };
			pattern_count_next = pattern_count_sub1;
		end
	end else begin
		if (start_line) begin
			vram_raddr_next = vram_rowbase;
			load_character_addr_next = 1'b1;
			preload1_next = 1'b1;
		end
		if (preload3) begin
			pattern_next = pattern_expand;
			pattern_count_next = PCOUNT;
			vram_raddr_next = vram_raddr_add1;
			load_character_addr_next = 1'b1;
		end
	end
end

always_ff @(posedge clk) begin
	pattern <= pattern_next;
	pattern_count <= pattern_count_next;
	preload1 <= preload1_next;
	preload2 <= preload2_next;
	preload3 <= preload3_next;
	load_character_addr <= load_character_addr_next;
	vram_raddr <= vram_raddr_next;
end

assign red = active ? { BPP {pattern[PWIDTH-1]} } : {BPP{1'b0}};
assign grn = active ? { BPP {pattern[PWIDTH-1]} } : {BPP{1'b0}};
assign blu = active ? { BPP {1'b1} } : {BPP{1'b0}};

endmodule
