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
 `ifdef ICE_STICK
   $display("-Os");   
 `else   
   $display("-O3");
 `endif   
end
endmodule
`endif

