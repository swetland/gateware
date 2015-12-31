module pll_12_25(REFERENCECLK,
                 PLLOUTCORE,
                 PLLOUTGLOBAL,
                 RESET,
                 LOCK);

input REFERENCECLK;
input RESET;    /* To initialize the simulation properly, the RESET signal (Active Low) must be asserted at the beginning of the simulation */ 
output PLLOUTCORE;
output PLLOUTGLOBAL;
output LOCK;

SB_PLL40_CORE pll_12_25_inst(.REFERENCECLK(REFERENCECLK),
                             .PLLOUTCORE(PLLOUTCORE),
                             .PLLOUTGLOBAL(PLLOUTGLOBAL),
                             .EXTFEEDBACK(),
                             .DYNAMICDELAY(),
                             .RESETB(RESET),
                             .BYPASS(1'b0),
                             .LATCHINPUTVALUE(),
                             .LOCK(LOCK),
                             .SDI(),
                             .SDO(),
                             .SCLK());

//\\ Fin=12, Fout=25;
defparam pll_12_25_inst.DIVR = 4'b0001;
defparam pll_12_25_inst.DIVF = 7'b1000010;
defparam pll_12_25_inst.DIVQ = 3'b100;
defparam pll_12_25_inst.FILTER_RANGE = 3'b001;
defparam pll_12_25_inst.FEEDBACK_PATH = "SIMPLE";
defparam pll_12_25_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
defparam pll_12_25_inst.FDA_FEEDBACK = 4'b0000;
defparam pll_12_25_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
defparam pll_12_25_inst.FDA_RELATIVE = 4'b0000;
defparam pll_12_25_inst.SHIFTREG_DIV_MODE = 2'b00;
defparam pll_12_25_inst.PLLOUT_SELECT = "GENCLK";
defparam pll_12_25_inst.ENABLE_ICEGATE = 1'b0;

endmodule
