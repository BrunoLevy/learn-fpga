// A PLL that generates a 250MHz clock from the 25 MHz clock.
// Generates also a 125 MHz clock (that can be used with the 
// DDR-based shifter, that shifts two bits per clock, but I'm
// not using it for now).
//
// Inspirations from:
//   https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/
//   https://github.com/sylefeb/Silice/blob/master/projects/common/hdmi_clock.v

module HDMI_clock (
        input  clk,            //  25 MHz
	output hdmi_clk        // 250 MHz
    );

`ifdef BENCH_OR_LINT
   assign hdmi_clk = clk;
`else
   
wire clkfb;
wire locked;

(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(0),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(2),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(4),
        .CLKOS_CPHASE(0),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(20),
        .CLKOS2_CPHASE(0),
        .CLKOS2_FPHASE(0),
        .CLKFB_DIV(10),
        .CLKI_DIV(1),
        .FEEDBK_PATH("INT_OP")
    ) pll_i (
        .CLKI(clk),
        .CLKFB(clkfb),
        .CLKINTFB(clkfb),
        .CLKOP(hdmi_clk),      // 250 MHz
//      .CLKOS(half_hdmi_clk), // 125 MHz
//      .CLKOS2(out_clk),      // 25  MHz
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b0),
        .PHASESTEP(1'b0),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);
`endif
    
endmodule

