/*
 * A dummy IVERILOG module to get some configured variables
 */

`include "femtosoc_config.v"

`ifdef GET_NRV_RAM
module dummy();
initial begin
   $display("%d",`NRV_RAM);
end
endmodule
`endif   
   
`ifdef GET_COPT_ARCH
module dummy();
initial begin
 `ifdef NRV_RV32M
   $display("rv32im");   
 `else   
   $display("rv32i");
 `endif   
end
endmodule
`endif

`ifdef GET_COPT_ABI
module dummy();
initial begin
   $display("ilp32");
end
endmodule
`endif
 
`ifdef GET_COPT_OPTIMIZE
module dummy();
initial begin
 `ifdef NRV_RV32M
   $display("-O3");   
 `else   
   $display("-Os");
 `endif   
end
endmodule
`endif

//   Note1: for now we only need FGA here for conditional
// compilation of OLED->FGA emulation (that pulls too
// much code on the IceStick). The rest of the code uses
// hardware config registers to query config and adapt
// dynamically.
//   Note2: need to be "-DXXX=1" rather than "-DXXX" because
// the makefile also passes that to the assembler after
// some text substitution, and the assembler needs "=1"
`ifdef GET_DEVICES
module dummy();
initial begin
`ifdef NRV_IO_FGA
   $display("-DFGA=1");   
`endif   
end
endmodule
`endif
