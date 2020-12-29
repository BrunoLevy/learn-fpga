/********************************* Large ALU **********************************/
// Large version of the ALU
// Implements the RV32IM instruction set, with MUL,DIV,REM
// Includes a barrel shifter (that shifts in 1 clock)

module NrvLargeALU #(
   parameter [0:0] LATCH_ALU = 0		     
)( 
  input 	     clk,      // clock
  input [31:0] 	     in1,      // <- The two inputs
  input [31:0] 	     in2,      // <-
  input [2:0] 	     func,     // Operation
  input 	     funcQual, // Operation qualification (+/-, Logical/Arithmetic)
  input              funcM,    // Asserted if operation is an RV32M operation
  output reg [31:0]  out,      // ALU result. Latched if operation is a shift,mul,div,rem
  output 	     busy,     // 1 if ALU is currently computing (that is, shift,mul,div,rem)
  input 	     wr,       // Raise to write ALU inputs and start computing
  output wire [31:0] AplusB    // Direct access to the adder, used by address computation  
);

   assign AplusB = in1 + in2;

   reg [31:0] ALUreg; // The internal register of the ALU, used by MUL(H)(U) and shifts.

   // Implementation of DIV/REM instructions, highly inspired by PICORV32
   reg [31:0] 	      dividend;
   reg [62:0] 	      divisor;
   reg [31:0] 	      quotient;
   reg [31:0] 	      quotient_msk;
   reg 		      outsign;

   assign busy = funcM && |quotient_msk; // ALU is busy if a DIV or REM operation is running.
      
   // Implementation suggested by Matthias Koch, uses a single 33 bits 
   // subtract for all the tests, as in swapforth/J1.
   // NOTE: if you read swapforth/J1 source,
   //   J1's st0,st1 are inverted as compared to in1,in2 (st0<->in2  st1<->in1)
   // Equivalent code:
   // case(func) 
   //    3'b000: out = funcQual ? in1 - in2 : in1 + in2;               // ADD/SUB
   //    3'b010: out = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0 ; // SLT
   //    3'b011: out = (in1 < in2) ? 32'b1 : 32'b0;                    // SLTU
   //    ...
	 
   wire [32:0] minus = {1'b1, ~in2} + {1'b0,in1} + 33'b1;
   wire        LT  = (in1[31] ^ in2[31]) ? in1[31] : minus[32];
   wire        LTU = minus[32];

   // Implementation of MUL instructions: using a single 33 * 33
   // multiplier, and doing sign extension or not according to
   // the signedness of the operands in instruction.
   // On the ECP5, yosys infers four 18x18 DSPs.
   // For FPGAs that don't have DSP blocks, we could use an
   // iterative algorithm instead (e.g., the one in FIRMWARE/LIB/mul.s)
   wire               in1U = (func == 3'b011);
   wire               in2U = (func == 3'b010 || func == 3'b011);
   wire signed [32:0] in1E = {in1U ? 1'b0 : in1[31], in1}; 
   wire signed [32:0] in2E = {in2U ? 1'b0 : in2[31], in2};
   wire signed [63:0] times = in1E * in2E;

   always @(*) begin
      if(funcM) begin
	 case(func)
	   3'b000: out <= ALUreg;                           // MUL
	   3'b001: out <= ALUreg;                           // MULH
	   3'b010: out <= ALUreg;                           // MULHSU
	   3'b011: out <= ALUreg;                           // MULHU
	   3'b100: out <= outsign ? -quotient : quotient;   // DIV
	   3'b101: out <= quotient;                         // DIVU
	   3'b110: out <= outsign ? -dividend : dividend;   // REM 
	   3'b111: out <= dividend;                         // REMU
	 endcase
      end else begin 
	 if(LATCH_ALU) begin
	    out = ALUreg;
	 end else begin
	 (* parallel_case, full_case *)
	    case(func)
              3'b000: out = funcQual ? minus[31:0] : AplusB;   // ADD/SUB
              3'b010: out = LT ;                               // SLT
              3'b011: out = LTU;                               // SLTU
              3'b100: out = in1 ^ in2;                         // XOR
              3'b110: out = in1 | in2;                         // OR
              3'b111: out = in1 & in2;                         // AND
	   
	      // We could generate the barrel shifter here, but doing so
	      // makes the critical path too long, so we keep a two-phase
	      // ALU instead.
              3'b001: out = ALUreg;                           // SLL	   
              3'b101: out = ALUreg;                           // SRL/SRA
	    endcase 
	 end
      end
   end 

   
   always @(posedge clk) begin
      
      /* verilator lint_off WIDTH */
      /* verilator lint_off CASEINCOMPLETE */

      if(funcM) begin
	 if(wr) begin 
	    case(func)
	      3'b000: ALUreg <= times[31:0];  // MUL
	      3'b001: ALUreg <= times[63:32]; // MULH
	      3'b010: ALUreg <= times[63:32]; // MULHSU
	      3'b011: ALUreg <= times[63:32]; // MULHU

	      // Initialize internal registers for
	      // DIV, DIVU, REM, REMU.
	      // DIV, and REM: extract operand signs,
	      // and get absolute value of operands.
	      3'b100: begin // DIV
		 dividend <= in1[31] ? -in1 : in1;
		 divisor  <= (in2[31] ? -in2 : in2) << 31;
		 outsign  <= (in1[31] != in2[31]) && |in2;
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
	      end
	      3'b101: begin // DIVU
		 dividend <= in1;
		 divisor  <= in2 << 31;
		 outsign  <= 1'b0;
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
	      end
	      3'b110: begin // REM
		 dividend <= in1[31] ? -in1 : in1;
		 divisor  <= (in2[31] ? -in2 : in2) << 31;		 
		 outsign  <= in1[31];
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
	      end
	      3'b111: begin // REMU
		 dividend <= in1;
		 divisor  <= in2 << 31;
		 outsign  <= 1'b0;
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
	      end
	    endcase // case (func)
	 end else begin // if (wr)
	    // The division algorithm is here.
	    // On exit, divisor is the remainder.
	    if(divisor <= dividend) begin
	       dividend <= dividend - divisor;
	       quotient <= quotient | quotient_msk;
	    end
	    divisor <= divisor >> 1;
	    quotient_msk <= quotient_msk >> 1;
	 end
      end else if(wr) begin // Barrel shifter, latched to reduce combinatorial depth.
	 if(LATCH_ALU) begin
	    case(func)
	      3'b000: ALUreg <= funcQual ? minus[31:0] : AplusB;   // ADD/SUB
	      3'b010: ALUreg <= LT ;                               // SLT
	      3'b011: ALUreg <= LTU;                               // SLTU
	      3'b100: ALUreg <= in1 ^ in2;                         // XOR
	      3'b110: ALUreg <= in1 | in2;                         // OR
	      3'b111: ALUreg <= in1 & in2;                         // AND
	      3'b001: ALUreg <= in1 << in2[4:0];                                        // SLL	   
	      3'b101: ALUreg <= $signed({funcQual ? in1[31] : 1'b0, in1}) >>> in2[4:0]; // SRL/SRA
	    endcase 
	 end else begin 
	    case(func)
	      3'b001: ALUreg <= in1 << in2[4:0];                                        // SLL	   
	      3'b101: ALUreg <= $signed({funcQual ? in1[31] : 1'b0, in1}) >>> in2[4:0]; // SRL/SRA
	    endcase 
	 end
      end 
      /* verilator lint_on WIDTH */
      /* verilator lint_on CASEINCOMPLETE */
   end 
endmodule
