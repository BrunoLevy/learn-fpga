/*
 * testbench for femtosoc/femtorv32
 *
 * 1. select one of the processors by uncommenting one of the
 *    lines NRV_FEMTORV32_XXX
 *
 * 2. edit FIRMWARE/config.mk and make sure ARCH corresponds to
 *    selected processor.
 *
 * $ cd FIRMWARE/EXAMPLES 
 * $ make hello.hex
 * $ cd ../..
 * $ make testbench
 * 
 * Uncomment VERBOSE for extensive information (states ...)
 */ 

`timescale 1ns/1ns

//`include "femtosoc_config.v"
//
//`ifndef BENCH
//`define BENCH
//`endif

`define VERBOSE // Uncomment to have detailed log traces of all states
`include "femtosoc.v"

`ifdef VERILATOR
module femtoRV32_bench(
    input pclk, 
    output oled_DIN, oled_CLK, oled_CS, oled_DC, oled_RST
);
`else
module femtoRV32_bench();
   reg pclk;
`endif

   wire [4:0] LEDs;
   wire TXD;
   femtosoc uut(
      .pclk(pclk),
      .TXD(TXD),
      .RXD(1'b0),
      .RESET(1'b0),

`ifdef NRV_IO_SSD1351_1331
      .oled_DIN(oled_DIN),
      .oled_CLK(oled_CLK),
      .oled_CS(oled_CS),
      .oled_DC(oled_DC),      
      .oled_RST(oled_RST),
`endif
      .D1(LEDs[0]),
      .D2(LEDs[1]),		 
      .D3(LEDs[2]),		 
      .D4(LEDs[3]),		 
      .D5(LEDs[4])
   );

`ifndef VERILATOR
   initial begin
      pclk = 0;
      forever begin
	 #1 pclk = ~pclk;
      end
   end
`endif

endmodule
