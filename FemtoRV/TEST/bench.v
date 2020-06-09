`define NRV_IO_LEDS

`define BENCH
//`define VERBOSE // Uncomment to have detailed log traces of all states
`include "../femtosoc.v"

module femtoRV32_bench();
   
   reg pclk;
   wire [4:0] LEDs;
   wire [4:0] oled_SPI;
//   wire oled_DIN, oled_CLK, oled_CS, oled_DC, oled_RST;

   femtosoc uut(
      .pclk(pclk),		 
      .D1(LEDs[0]),
      .D2(LEDs[1]),		 
      .D3(LEDs[2]),		 
      .D4(LEDs[3]),		 
      .D5(LEDs[4])
/*
      .oled_DIN(oled_SPI[0]),
      .oled_CLK(oled_SPI[1]),
      .oled_CS (oled_SPI[2]),
      .oled_DC (oled_SPI[3]),
      .oled_RST(oled_SPI[4])
 */
   );

   integer i;
   initial begin
      for(i=0; i<100000; i++) begin
	 #10 pclk = 0;
	 #10 pclk = 1;
      end
   end


endmodule
