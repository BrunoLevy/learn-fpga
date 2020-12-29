
/* PLL for ICE40 feather board */

module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);

   // Use DIVF and DIVQ values from 'icepll -i 12 -o freq'
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
	50: begin
	   parameter DIVF = 7'b1000010;
           parameter DIVQ = 3'b100;
	end
	45: begin
	   parameter DIVF = 7'b0111011;
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

   SB_PLL40_PAD #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(DIVF), 
      .DIVQ(DIVQ), 
      .FILTER_RANGE(3'b001),
   ) pll (
      .PACKAGEPIN(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );

endmodule  
