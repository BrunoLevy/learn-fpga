/************* The Control and Status registers ****************/

// For now we only implement some readonly CSRs

module NrvControlStatusRegisterFile(
   input wire clk,          // clock
   input wire instr_cnt,    // asserted once per instruction retired
   input wire reset,	    // resets CSRs to default value (aclive low)
   input wire [11:0] CSRid,  // 12-bits CSR ID
   output reg [31:0] rdata, // read CSR value
   output reg	     error  // set to 1 if invalid CSR ID		  
);

`ifdef NRV_COUNTERS
 `ifdef NRV_COUNTERS_64   
   reg [63:0] counter_cycle;
   reg [63:0] counter_instret;
 `else
   reg [31:0] counter_cycle;
   reg [31:0] counter_instret;
 `endif 
   always @(posedge clk) begin
      if(!reset) begin	    
	 counter_instret <= 0;
	 counter_cycle   <= 0;
      end else begin
	 counter_cycle <= counter_cycle+1;
	 if(instr_cnt) begin
	    counter_instret <= counter_instret+1;
	 end
      end
   end
`endif

always @(*) begin
   error = 1'b0;
   (* parallel_case, full_case *)
   case(CSRid) 
`ifdef NRV_COUNTERS
      12'b110000000000: rdata = counter_cycle[31:0];    // CYCLE
      12'b110000000001: rdata = counter_cycle[31:0];    // TIME (returns CYCLE)
      12'b110000000010: rdata = counter_instret[31:0];  // INSTRET
 `ifdef NRV_COUNTERS_64
      12'b110010000000: rdata = counter_cycle[63:32];   // CYCLEH
      12'b110010000001: rdata = counter_cycle[63:32];   // TIMEH (returns CYCLEH)
      12'b110010000010: rdata = counter_instret[63:32]; // INSTRETH
 `endif
`endif            
      default: begin
	 rdata = {32{1'bx}};
	 error = 1'b1;
      end
   endcase
end   
   
endmodule   
