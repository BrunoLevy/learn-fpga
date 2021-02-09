/*
 * A dummy IVERILOG module to get some configured variables
 */

`include "femtosoc_config.v"

module dummy();
initial begin
   
 `ifdef NRV_RV32M
   $display("ARCH=rv32im");
   $display("OPTIMIZE=-O3");      
 `else   
   $display("ARCH=rv32i");
   $display("OPTIMIZE=-Os");         
 `endif
   
   $display("ABI=ilp32");
   
   $display("RAM_SIZE=%d",`NRV_RAM);

//   Note1: for now we only need FGA here for conditional
// compilation of OLED->FGA emulation (that pulls too
// much code on the IceStick). The rest of the code uses
// hardware config registers to query config and adapt
// dynamically.
//   Note2: need to be "-DXXX=1" rather than "-DXXX" because
// the makefile also passes that to the assembler after
// some text substitution, and the assembler needs "=1"

   $write("DEVICES=");
`ifdef NRV_IO_FGA
   $write(" -DFGA=1");   
`endif   
`ifdef NRV_IO_SSD1351
   $write(" -DSSD1351=1");   
`endif   
`ifdef NRV_IO_SSD1331
   $write(" -DSSD1331=1");   
`endif
`ifdef NRV_IO_SDCARD
   $write(" -DSDCARD=1");   
`endif
`ifdef NRV_IO_MAPPED_SPI_FLASH
   $write(" -DSPIFLASH=1");   
`endif
`ifdef ICE_STICK
   $write(" -DICE_STICK=1");   
`endif
   $write("\n");
   
end 
endmodule


