/* PLL for ULX3S board */

module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);

   // Use values from ecpll -i 25 -o freq -f tmp.v
   generate
      case(freq)
        120: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 5;
	   localparam CLKOP_CPHASE = 2;
	   localparam CLKFB_DIV = 24;	   	   
	end
        110: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 5;
	   localparam CLKOP_CPHASE = 2;
	   localparam CLKFB_DIV = 22;	   	   
	end
        100: begin
	   localparam CLKI_DIV = 1;
	   localparam CLKOP_DIV = 6;
	   localparam CLKOP_CPHASE = 2;
	   localparam CLKFB_DIV = 4;	   	   
	end
	95: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 6;
	   localparam CLKOP_CPHASE = 3;
	   localparam CLKFB_DIV = 19;	   	   
	end
	90: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 7;
	   localparam CLKOP_CPHASE = 3;
	   localparam CLKFB_DIV = 18;	   	   
	end
	85: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 7;
	   localparam CLKOP_CPHASE = 3;
	   localparam CLKFB_DIV = 17;	   	   
        end
	80: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 7;
	   localparam CLKOP_CPHASE = 3;
	   localparam CLKFB_DIV = 16;	   	   
        end
	75: begin
	   localparam CLKI_DIV = 1;
	   localparam CLKOP_DIV = 8;
	   localparam CLKOP_CPHASE = 4;
	   localparam CLKFB_DIV = 3;	   	   
	end
	70: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 9;
	   localparam CLKOP_CPHASE = 4;
	   localparam CLKFB_DIV = 14;	   	   
	end
	65: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 9;
	   localparam CLKOP_CPHASE = 4;
	   localparam CLKFB_DIV = 13;	   	   
	end
	60: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 10;
	   localparam CLKOP_CPHASE = 4;
	   localparam CLKFB_DIV = 12;	   	   
	end
	50: begin
	   localparam CLKI_DIV = 1;
	   localparam CLKOP_DIV = 12;
	   localparam CLKOP_CPHASE = 5;
	   localparam CLKFB_DIV = 2;	   	   
	end
	40: begin
	   localparam CLKI_DIV = 5;
	   localparam CLKOP_DIV = 15;
	   localparam CLKOP_CPHASE = 7;
	   localparam CLKFB_DIV = 8;	   	   
	end
      endcase
   endgenerate

(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(CLKI_DIV),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(CLKOP_DIV),
        .CLKOP_CPHASE(CLKOP_CPHASE),
        .CLKOP_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(CLKFB_DIV)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(pclk),
        .CLKOP(clk),
        .CLKFB(clk),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0)
	);
endmodule  
