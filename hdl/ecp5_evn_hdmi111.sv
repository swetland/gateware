module top(
	input clk,
	input btn,
	output [7:0] led,
	output hdmi_r,
	output hdmi_g,
	output hdmi_b,
	output hdmi_hs,
	output hdmi_vs,
	output hdmi_de,
	output hdmi_ck
);

	assign led = { 4'b1010, btn, btn, btn, btn };

wire clk25m;

pll_12_25 pll(
	.clk12m_in(clk),
	.clk25m_out(clk25m),
	.locked()
);

assign hdmi_ck = clk25m;

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
endmodule
