// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: memory-mapped constants to query 
//   hardware config.

module HardwareConfig(
    input wire 	       clk, 
    input wire 	       sel_memory,  // available RAM
    input wire 	       sel_devices, // configured devices 
    input wire         sel_cpuinfo, // CPU information 	      
    output wire [31:0] rdata        // read data
);

`include "HardwareConfig_bits.v"   

// configured devices
localparam NRV_DEVICES = 0
`ifdef NRV_IO_LEDS
   | (1 << IO_LEDS_bit)			 
`endif			    
`ifdef NRV_IO_UART
   | (1 << IO_UART_DAT_bit) | (1 << IO_UART_CNTL_bit)
`endif			    
`ifdef NRV_IO_SSD1351
   | (1 << IO_SSD1351_CNTL_bit) | (1 << IO_SSD1351_CMD_bit) | (1 << IO_SSD1351_DAT_bit)
`endif			    
`ifdef NRV_IO_MAX7219     
   | (1 << IO_MAX7219_DAT_bit) 
`endif			    
`ifdef NRV_IO_SPI_FLASH
   | (1 << IO_SPI_FLASH_bit) 			 
`endif			    
`ifdef NRV_IO_MAPPED_SPI_FLASH
   | (1 << IO_MAPPED_SPI_FLASH_bit) 			 
`endif			    
`ifdef NRV_IO_SDCARD
   | (1 << IO_SDCARD_bit) 			 			 
`endif			    
`ifdef NRV_IO_BUTTONS
   | (1 << IO_BUTTONS_bit) 			 			 			 
`endif 
`ifdef NRV_IO_FGA
   | (1 << IO_FGA_CNTL_bit) | (1 << IO_FGA_CMD_bit)
`endif			 
;

// CPL (Cycles per Loop)
// number of cycles for each
// iteration of:
// wait: sub a0, a0, a1
//       bgt a0, zero, wait
`ifdef NRV_MINIRV32
   localparam NRV_CPL = 9;
`else
 `ifdef NRV_LATCH_ALU
   localparam NRV_CPL = 7;
 `else
   localparam NRV_CPL = 6;
 `endif
`endif
	
   assign rdata = sel_memory  ? `NRV_RAM  :
		  sel_devices ?  NRV_DEVICES :
                  sel_cpuinfo ? (`NRV_FREQ << 16) | (NRV_CPL << 26) : 32'b0;
   
endmodule
