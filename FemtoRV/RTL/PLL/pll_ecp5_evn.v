/* PLL for ECP5 evaluation board */

module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);

      // I think that: output freq = 12 Mhz * CLKFB_DIV * (12 / CLKI_DIV) / CLKOP_DIV
      // (to be double-checked...)
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
        .CLKOP_DIV(12),      // divide outplut clock
        .CLKFB_DIV(25),      // divide feedback signal = multiply output clock
        .CLKI_DIV(300/freq), // reference clock divider  
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
   
endmodule  
