/*
 *  The PLL, that generates the internal clock (high freq) from the 
 * external one (lower freq).
 *  Trying to make something that is portable between different boards
 * (for now, ICEStick and ECP5 evaluation boards supported).
 */ 

module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);

`ifdef BENCH

  assign clk = pclk;

`elsif ULX3S
   
  assign clk = pclk;
   
`elsif ICE40

   // Use DIVF and DIVQ values from icepll -o freq
   generate
      case(freq)
        100: begin
	   parameter DIVF = 7'b1000010;
	   parameter DIVQ = 3'b011;
	end
	95: begin
	   parameter DIVF = 7'b0111110;
	   parameter DIVQ = 3'b011;
	end
	90: begin
	   parameter DIVF = 7'b0111011;
	   parameter DIVQ = 3'b011;
	end
	85: begin
	   parameter DIVF = 7'b0111000;
	   parameter DIVQ = 3'b011;
        end
	80: begin
	   parameter DIVF = 7'b0110100;
	   parameter DIVQ = 3'b011;
        end
	75: begin
	   parameter DIVF = 7'b0110001;
	   parameter DIVQ = 3'b011;
	end
	70: begin
	   parameter DIVF = 7'b0101110;
	   parameter DIVQ = 3'b011;
	end
	65: begin
	   parameter DIVF = 7'b1010110;
           parameter DIVQ = 3'b100;
	end
	60: begin
	   parameter DIVF = 7'b1001111;
           parameter DIVQ = 3'b100;
	end
	40: begin
	   parameter DIVF = 7'b0110100;
	   parameter DIVQ = 3'b100;
	end
	30: begin
	   parameter DIVF = 7'b1001111;
	   parameter DIVQ = 3'b101;
	end
      endcase
   endgenerate

   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(DIVF), 
      .DIVQ(DIVQ), 
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
`endif
endmodule  
