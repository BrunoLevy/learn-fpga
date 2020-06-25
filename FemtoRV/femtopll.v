/*
 *  The PLL, that generates the internal clock (high freq) from the 
 * external one (lower freq).
 *  Trying to make something that is portable between different boards
 * (for now, ICEStick and ECP5 evaluation board supported).
 */ 

module femtoPLL /* #(
 parameter freq = 60
) */ (
 input 	pclk,
 output clk	   
);
   
`ifdef BENCH
  assign clk = pclk;
`elsif ICE40
   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      //.DIVF(7'b0111011), .DIVQ(3'b011), // 90 MHz (too fast)
      //.DIVF(7'b0110100), .DIVQ(3'b011), // 80 MHz (seems to work)
      //.DIVF(7'b0110001), .DIVQ(3'b011), // 75 MHz
      .DIVF(7'b1001111), .DIVQ(3'b100), // 60 MHz
      //.DIVF(7'b0110100), .DIVQ(3'b100), // 40 MHz
      //.DIVF(7'b1001111), .DIVQ(3'b101), // 30 MHz
      .FILTER_RANGE(3'b001),
   ) pll (
      .REFERENCECLK(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );
`elsif ECP5
      // I think that: output freq = 12 Mhz * CLKFB_DIV * (12 / CLKI_DIV) / CLKOP_DIV
      // CLKI_DIV = 2 -> 150 MHz
      // CLKI_DIV = 5 -> 60 MHz      
      // CLKI_DIV = 6 -> 50 MHz

    (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(11),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(12), // divide outplut clock
        .CLKFB_DIV(25), // divide feedback signal = multiply output clock
        .CLKI_DIV(5),   // reference clock divider  
        .FEEDBK_PATH("CLKOP")
    ) pll (
        .CLKI(pclk),
        .CLKFB(clk),
        .CLKOP(clk),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
    );
`endif
endmodule  
