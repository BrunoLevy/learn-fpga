/*
 * testbench for femtosoc/femtorv32
 * 
 * $ cd FIRMWARE
 * $ ./make_firmware.sh ASM_EXAMPLES/bench_count_15.S
 * $ cd ..
 * $ make test
 * 
 * Everything that is sent to the LEDs is displayed to the console
 * Uncomment VERBOSE for extensive information (states ...)
 */ 

`define NRV_IO_LEDS
`define NRV_IO_UART
`define NRV_FREQ 1

//`define NRV_FEMTORV32_QUARK
//`define NRV_FEMTORV32_ELECTRON
//`define NRV_FEMTORV32_INTERMISSUM
`define NRV_FEMTORV32_GRACILIS

`define NRV_RESET_ADDR 0
`define NRV_RAM 65536
`define NRV_IO_HARDWARE_CONFIG
`define NRV_CONFIGURED

`define BENCH
`define VERBOSE // Uncomment to have detailed log traces of all states
`include "femtosoc.v"

module femtoRV32_bench();
   
   reg pclk;
   wire [4:0] LEDs;
   femtosoc uut(
      .pclk(pclk),
      .RXD(1'b0),		
      .D1(LEDs[0]),
      .D2(LEDs[1]),		 
      .D3(LEDs[2]),		 
      .D4(LEDs[3]),		 
      .D5(LEDs[4])
   );

   initial begin
      while(1) begin
	 #10 pclk = 0;
	 #10 pclk = 1;
      end
   end


endmodule
