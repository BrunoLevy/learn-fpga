/* PLL for FOMU board */

module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);

   // pclk: 48 MHz -> clk: 24 MHz
   reg cnt;
   always @(posedge pclk) begin
      cnt <= ~cnt;
   end
   assign clk = cnt;
   
endmodule  
