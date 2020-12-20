// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: memory-mapped constants to query 
//   hardware config.

module HardwareConfig(
    input wire         clk,		      
    input wire 	       sel_memory, // available RAM
    input wire 	       sel_devices_freq, // configured devices and freq	       
    output wire [31:0] rdata             // read data
);

`include "HardwareConfig_bits.v"   
	
   assign rdata = sel_memory       ? `NRV_RAM                          :
		  sel_devices_freq ? (NRV_DEVICES | (`NRV_FREQ << 16)) : 32'b0;
   
endmodule
