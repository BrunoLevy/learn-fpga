/********************************* Small ALU **********************************/
// Small version of the ALU
// To be used on the ICEStick, when NRV_RV32M is not set.
// Implements the RV32I instruction set.

module NrvSmallALU #(
   parameter [0:0] TWOSTAGE_SHIFTER = 0 // optional twostage shifter, makes shifts faster
		                        // (but eats up 60 LUTs or so)
)(
  input 	    clk, 
  input [31:0] 	    in1,
  input [31:0] 	    in2,
  input [2:0] 	    op,     // Operation
  input 	    opqual, // Operation qualification (+/-, Logical/Arithmetic)
  output reg [31:0] out,    // ALU result. Latched if operation is a shift
  output 	    busy,   // 1 if ALU is currently computing (that is, shift)
  input 	    wr      // Raise to write ALU inputs and start computing
);

   reg [31:0] ALUreg;          // The internal register of the ALU, used by shifts.
   reg [4:0]  shamt = 0;       // current shift amount.
   assign busy = (shamt != 0); // ALU is busy if shift amount is non-zero.
      
   // Implementation suggested by Matthias Koch, uses a single 33 bits 
   // subtract for all the tests, as in swapforth/J1.
   // NOTE: if you read swapforth/J1 source,
   //   J1's st0,st1 are inverted as compared to in1,in2 (st0<->in2  st1<->in1)
   // Equivalent code:
   // case(op) 
   //    3'b000: out = opqual ? in1 - in2 : in1 + in2;                 // ADD/SUB
   //    3'b010: out = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0 ; // SLT
   //    3'b011: out = (in1 < in2) ? 32'b1 : 32'b0;                    // SLTU
   //    ...
	 
   wire [32:0] minus = {1'b1, ~in2} + {1'b0,in1} + 33'b1;
   wire        LT  = (in1[31] ^ in2[31]) ? in1[31] : minus[32];
   wire        LTU = minus[32];

   always @(*) begin
      (* parallel_case, full_case *)
      case(op)
	3'b000: out = opqual ? minus[31:0] : in1 + in2;  // ADD/SUB
	3'b010: out = LT ;                               // SLT
	3'b011: out = LTU;                               // SLTU
	3'b100: out = in1 ^ in2;                         // XOR
	3'b110: out = in1 | in2;                         // OR
	3'b111: out = in1 & in2;                         // AND
	
	// Shift operations, get result from the shifter
	3'b001: out = ALUreg;                           // SLL	   
	3'b101: out = ALUreg;                           // SRL/SRA
      endcase // case (op)
   end
   
   always @(posedge clk) begin
      
      /* verilator lint_off WIDTH */
      /* verilator lint_off CASEINCOMPLETE */

      if(wr) begin
	 case(op)
	   3'b001: begin ALUreg <= in1; shamt <= in2[4:0]; end // SLL	   
	   3'b101: begin ALUreg <= in1; shamt <= in2[4:0]; end // SRL/SRA
	 endcase 
      end else begin
	 if (TWOSTAGE_SHIFTER && shamt > 4) begin
	    shamt <= shamt - 4;
	    case(op)
	      3'b001: ALUreg <= ALUreg << 4;                               // SLL
	      3'b101: ALUreg <= opqual ? {{4{ALUreg[31]}}, ALUreg[31:4]} : // SRL/SRA 
                                         { 4'b0000,        ALUreg[31:4]} ; 
	    endcase 
	 end else  
	   if (shamt != 0) begin
	      shamt <= shamt - 1;
	      case(op)
		3'b001: ALUreg <= ALUreg << 1;                          // SLL
		3'b101: ALUreg <= opqual ? {ALUreg[31], ALUreg[31:1]} : // SRL/SRA 
				           {1'b0,       ALUreg[31:1]} ; 
	      endcase 
	   end
      end 
      /* verilator lint_on WIDTH */
      /* verilator lint_on CASEINCOMPLETE */
   end 
endmodule

