Episode III: the register file
---------------------------

Following the [stackoverflow answer](https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog/51621153#51621153),
at each clock tick, our register file will read two register values
and optionally write one. In addition, we learn from the RISC-V
specification that there is a special register `zero`, that returns always 0 when read, and 
that ignores what is written to it. Here is a _simplified_ version of the register file:

```
module NrvRegisterFile(
  input 	    clk, 
  input [31:0] 	    in,        // Data for write back register
  input [4:0] 	    inRegId,   // Register to write back to
  input 	    inEn,      // Enable register write back
  input [4:0] 	    outRegId1, // Register number for out1
  input [4:0] 	    outRegId2, // Register number for out2
  output reg [31:0] out1,      // Data out 1, available one clock after outRegId1 is set
  output reg [31:0] out2       // Data out 2, available one clock after outRegId2 is set
);
   reg [31:0]  bank1 [31:0];
   reg [31:0]  bank2 [31:0];
   always @(posedge clk) begin
      if (inEn) begin
	 if(inRegId != 0) begin 
	    bank1[inRegId] <= in;
	    bank2[inRegId] <= in;
	 end	  
      end 
      out1 <= bank1[outRegId1];
      out2 <= bank2[outRegId2];
   end 
endmodule
```

We need to read two registers (for instance, the two
operands of an ALU operation). Normally we would need two cycles, but if
we _duplicate_ the entire register file, we can do that in a single
cycle (this is why there is `bank1` and `bank2`).

_In fact if you take a look at `femtorv32.v`, it is slightly different:
there is a smarter way of treating register `zero`, taken from
Claire Wolf's [PicoRV32 sources](https://github.com/cliffordwolf/picorv32), by
negating the register index._ 

[Next](FemtoRV32_IV.md)