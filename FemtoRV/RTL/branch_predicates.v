/********************* Branch predicates *******************************/

module NrvPredicate(
   input [31:0] in1,
   input [31:0] in2,
   input [2:0]  op, // Operation
   output reg   out
);

   // Implementation suggested by Matthias Koch, uses a single 33 bits 
   // subtract for all the tests, as in swapforth/J1.
   // NOTE: if you read swapforth/J1 source, J1's st0,st1 are inverted 
   // as compared to in1,in2 (st0<->in2  st1<->in1)
   // Equivalent code:
   // case(op)
   //   3'b000: out = (in1 == in2);                   // BEQ
   //   3'b001: out = (in1 != in2);                   // BNE
   //   3'b100: out = ($signed(in1) < $signed(in2));  // BLT
   //   3'b101: out = ($signed(in1) >= $signed(in2)); // BGE
   //   3'b110: out = (in1 < in2);                    // BLTU
   //   3'b111: out = (in1 >= in2);                   // BGEU
   //   ...

   wire [32:0] 	minus = {1'b1, ~in2} + {1'b0,in1} + 33'b1;
   wire 	LT  = (in1[31] ^ in2[31]) ? in1[31] : minus[32];
   wire 	LTU = minus[32];
   wire 	EQ  = (minus[31:0] == 0);
      
   always @(*) begin
      (* parallel_case, full_case *)	 
      case(op)
        3'b000: out =  EQ;   // BEQ
        3'b001: out = !EQ;   // BNE
        3'b100: out =  LT;   // BLT
        3'b101: out = !LT;   // BGE
        3'b110: out =  LTU;  // BLTU
	3'b111: out = !LTU;  // BGEU
	default: out = 1'bx; // don't care...
      endcase
   end 
   
endmodule
