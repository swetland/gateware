`default_nettype none
`timescale 1ps/1ps

module mmcm_100m_25m (
	output wire clk25m_o,
  	input wire clk100m_i
	);

wire clk100m_ibufg;
wire clk25m_bufg;

IBUF clkin1_ibufg(
	.O(clk100m_ibufg),
	.I(clk100m_i)
	);

	/*
wire clkfbout;
wire clkfbin;

MMCME2_ADV #(.BANDWIDTH("OPTIMIZED"),
	.CLKOUT4_CASCADE("FALSE"),
	.COMPENSATION("FOO"),
	.STARTUP_WAIT("FALSE"),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT_F(9.125),
	.CLKFBOUT_PHASE(0.000),
	.CLKFBOUT_USE_FINE_PS("FALSE"),
	.CLKOUT0_DIVIDE_F(36.500),
	.CLKOUT0_PHASE(0.000),
	.CLKOUT0_DUTY_CYCLE(0.500),
	.CLKOUT0_USE_FINE_PS("FALSE"),
	.CLKIN1_PERIOD(10.000)
	) mmcm_adv (
	.CLKFBOUT(clkfbout),
	.CLKOUT0(clk25m_bufg),
	.CLKFBOUTB(),
	.CLKOUT0B(),
	.CLKOUT1(),
	.CLKOUT1B(),
	.CLKOUT2(),
	.CLKOUT2B(),
	.CLKOUT3(),
	.CLKOUT3B(),
	.CLKOUT4(),
	.CLKOUT5(),
	.CLKOUT6(),
	.CLKFBIN(clkfbin),
	.CLKIN1(clk100m_ibufg),
	.CLKIN2(1'b0),
	.CLKINSEL(1'b1),
	.DADDR(7'h0),
	.DCLK(1'b0),
	.DEN(1'b0),
	.DI(16'h0),
	.DO(),
	.DRDY(),
	.DWE(1'b0),
	.PSCLK(1'b0),
	.PSEN(1'b0),
	.PSINCDEC(1'b0),
	.PSDONE(),
	.LOCKED(),
	.CLKINSTOPPED(),
	.CLKFBSTOPPED(),
	.PWRDWN(1'b0),
	.RST(1'b0)
	);
BUFG clkfb_buf(
	.O(clkfbin),
	.I(clkfbout)
	);

	*/

wire feedback;

PLLE2_ADV #(
	.BANDWIDTH("OPTIMIZED"),
	.COMPENSATION("INTERNAL"),
	.STARTUP_WAIT("FALSE"),
	.DIVCLK_DIVIDE(4),
	.CLKFBOUT_MULT(33),
	.CLKFBOUT_PHASE(0.000),
	.CLKOUT0_DIVIDE(33),
	.CLKOUT0_PHASE(0.000),
	.CLKOUT0_DUTY_CYCLE(0.500),
	.CLKIN1_PERIOD(10.000)
	) plle2_adv_inst (
	.CLKFBOUT(feedback),
	.CLKOUT0(clk25m_bufg),
	.CLKOUT1(),
	.CLKOUT2(),
	.CLKOUT3(),
	.CLKOUT4(),
	.CLKOUT5(),
	.CLKFBIN(feedback),
	.CLKIN1(clk100m_ibufg),
	.CLKIN2(1'b0),
	.CLKINSEL(1'b1),
	.DADDR(7'h0),
	.DCLK(1'b0),
	.DEN(1'b0),
	.DI(16'h0),
	.DO(),
	.DRDY(),
	.DWE(1'b0),
	.LOCKED(),
	.PWRDWN(1'b0),
	.RST(1'b0));

BUFG clkout1_buf(
	.O(clk25m_o),
	.I(clk25m_bufg)
	);

endmodule
