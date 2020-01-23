
`default_nettype none

module top(
	input wire clk,
	input wire [3:0]btn,
	output wire hdmi_r,
	output wire hdmi_g,
	output wire hdmi_b,
	output wire hdmi_hs,
	output wire hdmi_vs,
	output wire hdmi_ck,
	output wire hdmi_de,
	output reg [3:0]led
);

wire clk25m;

assign hdmi_ck = clk25m;

mmcm_100m_25m pll(
    .clk100m_i(clk),
    .clk25m_o(clk25m)
    );
    
always_ff @(posedge clk25m) begin
	led[0] <= btn[0];
	led[1] <= btn[1];
	led[2] <= btn[2];
	led[3] <= btn[3];
end

`ifdef OLDECODE
vga40x30x2 #(
    .BPP(1),
    .RGB(0)
    )hdmi(
    .clk25m(clk25m),
    .red(hdmi_r),
    .grn(hdmi_g),
    .blu(hdmi_b),
    .hs(hdmi_hs),
    .vs(hdmi_vs),
    .fr(),
    .active(hdmi_de),
    .vram_clk(clk25m),
    .vram_waddr(0),
    .vram_wdata(0),
    .vram_we(0)
    );
`else
display #(
	.BPP(1)
	) display0 (
	.clk(clk25m),
	.red(hdmi_r),
	.grn(hdmi_g),
	.blu(hdmi_b),
	.hsync(hdmi_hs),
	.vsync(hdmi_vs),
	.active(hdmi_de),
	.frame(),
	.wclk(clk25m),
	.waddr(0),
	.wdata(0),
	.we(0)
);
`endif

endmodule
