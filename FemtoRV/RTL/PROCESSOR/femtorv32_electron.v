/*******************************************************************/
// FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
// This version: The "Electron". 
// Implements RV32IM and has a barrel shifter.
//
// Instruction set: RV32IM + RDCYCLES
//
// Parameters:
//  Reset address can be defined using RESET_ADDR (default is 0).
//
//  The ADDR_WIDTH parameter lets you define the width of the internal
//  address bus (and address computation logic).
//
// Macros:
//    optionally one may define NRV_IS_IO_ADDR(addr), that is supposed to:
//              evaluate to 1 if addr is in mapped IO space, 
//              evaluate to 0 otherwise
//    (additional wait states are used when in IO space).
//    If left undefined, wait states are always used.
//
// Bruno Levy, Matthias Koch, 2020-2021
/*******************************************************************/

`define NRV_ARCH     "rv32im"
`define NRV_OPTIMIZE "-O3"

// The ALU, used for reg-reg, reg-imm and branch tests
module ALU(
  input 	clk,   
  input 	wr,        // write strobe to start ALU and predicate computation
  input 	isALU,     // asserted is current instr is ALUimm or ALUreg or RV32M
  input [31:0] 	in1,       // \
  input [31:0] 	in2,       //  > ALU input and output 
  output [31:0] out,       // /
  output 	predicate, // test result for branch (continuous assignment)
  output 	busy,      // asserted if ALU is busy computing (RV32IM only)
  input [2:0] 	funct3,    // 3-bits code for ALU and tests (instr[14:12])
  input 	add_sub,   // 0 for add, 1 for sub
  input 	srl_sra,   // 0 for logical right shift, 1 for arithmetic right shift
  input         isRV32M	   // asserted if RV32M instr  (instr[25])
);
   reg [31:0] A;    // The internal register of the ALU.
   assign out = A;

   wire [31:0] plus = in1 + in2; 
   
   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] minus = {1'b1, ~in2} + {1'b0,in1} + 33'b1;

   // Predicates
   wire LT  = (in1[31] ^ in2[31]) ? in1[31] : minus[32];
   wire LTU = minus[32];
   wire EQ  = (minus[31:0] == 0);

   // The shifter
   // A right-shifter is used for left and right shifts.
   // Its input/output is flipped for left shifts.
   
   function [31:0] flip;
      input [31:0] x;
      flip = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
              x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
              x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
              x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]} ;
   endfunction
   
   wire [31:0] shifter_in = funct3[2] ? in1 : flip(in1);
   /* verilator lint_off WIDTH */
   wire [31:0] shifter   = $signed({srl_sra & in1[31], shifter_in}) >>> in2[4:0];
   /* verilator lint_on WIDTH */
   wire [31:0] leftshift = flip(shifter);

   // RV32M MUL, MULH, MULHSU, MULHU
   // Using a 33x33 bits signed multiply for all signed/unsigned
   // configurations. Yosys synthethizes a DSP block. For FPGAs that
   // do not have DSP blocks, one can use an interative algorithm 
   // instead (left as an excercise...).

   wire isMUL    = (funct3 == 3'b000);
   wire isMULH   = (funct3 == 3'b001);
// wire isMULHSU = (funct3 == 3'b010);
   wire isMULHU  = (funct3 == 3'b011);   

   wire sign1 = in1[31] & !isMULHU;
   wire sign2 = in2[31] & (isMUL|isMULH);
   wire signed [32:0] signed1 = {sign1, in1};
   wire signed [32:0] signed2 = {sign2, in2};
   wire signed [63:0] multiply = signed1 * signed2;

   // RV32M DIV/REM instructions, highly inspired by PICORV32
   reg 	      div_sign;
   reg 	      div_busy;
   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;
   reg 	      div_finished;
   assign busy = div_busy;
   
   always @(posedge clk) begin
      if(wr) begin
	 if(isRV32M) begin
	    div_busy <= funct3[2]; // funct3[2] is 1 for DIV,REM,DIVU,REMU
	    case(funct3)
	      // MUL (1 cycle, using DSP)
	      3'b000: A <= multiply[31:0];

	      // MULH, MULHSU, MULHU (1 cycle, using DSP)
	      3'b001, 3'b010, 3'b011 : A <= multiply[63:32];

	      // DIV, REM (initialize iterative algorithm)
              3'b100, 3'b110: begin
		 // compute |in1|/|in2|, reinject sign after
		 dividend <=          in1[31] ? -in1 : in1;
		 divisor  <= {31'b0, (in2[31] ? -in2 : in2)} << 31;
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
		 div_sign <= funct3[1] ? in1[31]                      // REM
			               : (in1[31] != in2[31]) & |in2; // DIV
              end

	      // DIVU, REMU (initialize iterative algorithm)
              3'b101, 3'b111: begin 
		 dividend <= in1;
		 divisor  <= {31'b0, in2} << 31;
		 quotient <= 0;
		 quotient_msk <= 1 << 31;
		 div_sign <= 1'b0;
              end
	    endcase	    
	 end else begin 
	    // RV32I functions (1 cycle)
	    case(funct3) 
              3'b000: A <= add_sub ? minus[31:0] : plus; // ADD/SUB
              3'b010: A <= {31'b0, LT} ;                 // SLT
              3'b011: A <= {31'b0, LTU};                 // SLTU
              3'b100: A <= in1 ^ in2;                    // XOR
              3'b110: A <= in1 | in2;                    // OR
              3'b111: A <= in1 & in2;                    // AND
              3'b001: A <= leftshift;                    // SLL
	      3'b101: A <= shifter;                      // SRL/SRA
            endcase 
	 end 
      end else if(div_busy) begin // DIV, REM, DIVU, REMU (iterative algorithm)
         divisor <= divisor >> 1;
         {quotient_msk, div_finished} <= {quotient_msk, div_finished} >> 1;
	 if((divisor <= {31'b0, dividend})) begin
	    quotient <= quotient | quotient_msk;
	    dividend <= dividend - divisor[31:0];
	 end
	 // 1 additional cycle to write-back result to A and reinject sign (DIV/REM)
	 if(div_finished) begin
	    div_finished <= 1'b0;
	    div_busy <= 1'b0;
	    case({funct3[1],div_sign}) // funct3[1]: 0->DIV 1->REM
	      2'b00: A <=  quotient;
	      2'b01: A <= -quotient;
	      2'b10: A <=  dividend;
	      2'b11: A <= -dividend;
	    endcase
	 end
      end
   end

   // Decoded ALU function as 1-hot: funct3Equals[i] <=> funct3 == i
   // (using it reduces overall LUT count)
   (* onehot *)
   wire [7:0] funct3Equals = 8'b00000001 << funct3;  

   assign predicate =
        funct3Equals[0] &  EQ  | // BEQ
        funct3Equals[1] & !EQ  | // BNE
        funct3Equals[4] &  LT  | // BLT
        funct3Equals[5] & !LT  | // BGE
        funct3Equals[6] &  LTU | // BLTU
        funct3Equals[7] & !LTU ; // BGEU
endmodule

/*******************************************************************/

module FemtoRV32(
   input          clk,

   output [31:0] mem_addr,  // address bus
   output [31:0] mem_wdata, // data to be written
   output [3:0]  mem_wmask, // write mask for the 4 bytes of each word
   input  [31:0] mem_rdata, // input lines for both data and instr
   output        mem_rstrb, // active to initiate memory read (used by IO)
   input         mem_rbusy, // asserted if memory is busy reading value
   input         mem_wbusy, // asserted if memory is busy writing value

   input         reset      // set to 0 to reset the processor
);

   parameter RESET_ADDR       = 32'h00000000; 
   parameter ADDR_WIDTH       = 24;           

   localparam ADDR_PAD = {(32-ADDR_WIDTH){1'b0}}; // 32-bits padding for addrs

 /***************************************************************************/
 // Instruction decoding.
 /***************************************************************************/

 // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction. 
 // Reference: Table page 104 of:
 // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

 // The destination register
 wire [4:0] rdId = instr[11:7];

 // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
 // It is used as follows: funct3Is[val] <=> funct3 == val
 (* onehot *)
 wire [7:0] funct3Is = 8'b00000001 << instr[14:12];

 // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
 wire [31:0] Uimm = {    instr[31],   instr[30:12], {12{1'b0}}};
 wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
 /* verilator lint_off UNUSED */ // MSBs of SBJimms are not used by addr adder. 
 wire [31:0] Simm = {{21{instr[31]}}, instr[30:25],instr[11:7]};
 wire [31:0] Bimm = {{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
 wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
 /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isStore   =  (instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   wire isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
   wire isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
   wire isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- cycles

   wire isALU = isALUimm | isALUreg;

   /***************************************************************************/
   // The register file.
   /***************************************************************************/
   
   reg [31:0] rs1;
   reg [31:0] rs2;
   reg [31:0] registerFile [31:0];

   always @(posedge clk) begin
     if (writeBack)
       if (rdId != 0)
         registerFile[rdId] <= writeBackData;
   end

   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except shifts.
   /***************************************************************************/

   wire aluWr;
   wire [31:0] aluOut;
   wire        predicate;
   wire        aluBusy;

   ALU alu(
     .clk(clk),
     .wr(aluWr),
     .isALU(isALU),
     .isRV32M(instr[5] & instr[25]), // instr[5] for isALUreg and instr[25] for RV32M	   
     .in1(rs1),
     .in2(isALUimm ? Iimm : rs2),
     .out(aluOut),
     .predicate(predicate),
     .busy(aluBusy),
     .funct3(instr[14:12]),
     .add_sub(instr[30] & instr[5]), // instr[30] is 1 for SUB and 0 for ADD, need to test also instr[5] because ADDI imm uses bit 30 !
     .srl_sra(instr[30])	   
   );
   
   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instr set).

   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   reg [ADDR_WIDTH-1:0]  PCplusImm;

   // A separate adder to compute JALR address
   reg [ADDR_WIDTH-1:0]  rs1plusImm;

   // A separate adder to compute the destination of load/store.   
   reg [ADDR_WIDTH-1:0]  loadstore_addr;
   
   assign mem_addr = {ADDR_PAD, 
		       state[WAIT_INSTR_bit] | state[FETCH_INSTR_bit] ? 
		       PC : loadstore_addr
		     };

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
      /* verilator lint_off WIDTH */	       	       
      (isSYSTEM            ? cycles               : 32'b0) |  // SYSTEM
      /* verilator lint_on WIDTH */	       	       	       
      (isLUI               ? Uimm                 : 32'b0) |  // LUI
      (isALU               ? aluOut               : 32'b0) |  // ALUreg, ALUimm
      (isAUIPC             ? {ADDR_PAD,PCplusImm} : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? {ADDR_PAD,PCplus4  } : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data            : 32'b0);   // Load

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned halfword
   // and byte load/store, based on:
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     = instr[13:12] == 2'b00; // funct3[1:0] == 2'b00;
   wire mem_halfwordAccess = instr[13:12] == 2'b01; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion

   wire LOAD_sign = 
	!instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   wire [15:0] LOAD_halfword = 
	       loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];
   
   wire  [7:0] LOAD_byte = 
	       loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE

   assign mem_wdata[ 7: 0] = rs2[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  : 
			     loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword 
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte     
   //                                (depending on loadstore_addr[1:0])

   wire [3:0] STORE_wmask =
	      mem_byteAccess      ? 
	            (loadstore_addr[1] ? 
		          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
		          (loadstore_addr[0] ? 4'b0010 : 4'b0001) 
                    ) :
	      mem_halfwordAccess ? 
	            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   /*************************************************************************/
   // And, last but not least, the state machine.
   /*************************************************************************/

   localparam FETCH_INSTR_bit     = 0;
   localparam WAIT_INSTR_bit      = 1;
   localparam EXECUTE1_bit        = 2;
   localparam EXECUTE2_bit        = 3;   
   localparam WAIT_ALU_OR_MEM_bit = 4;
   localparam NB_STATES           = 5;

   localparam FETCH_INSTR     = 1 << FETCH_INSTR_bit;
   localparam WAIT_INSTR      = 1 << WAIT_INSTR_bit;
   localparam EXECUTE1        = 1 << EXECUTE1_bit;
   localparam EXECUTE2        = 1 << EXECUTE2_bit;   
   localparam WAIT_ALU_OR_MEM = 1 << WAIT_ALU_OR_MEM_bit;
   
   (* onehot *)
   reg [NB_STATES-1:0] state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.

   // register write-back enable.
   wire writeBack = ~(isBranch | isStore ) & 
	            (state[EXECUTE2_bit] | state[WAIT_ALU_OR_MEM_bit]);

   // The memory-read signal.
   assign mem_rstrb = state[EXECUTE2_bit] & isLoad | state[FETCH_INSTR_bit];

   // The mask for memory-write.
   assign mem_wmask = {4{state[EXECUTE2_bit] & isStore}} & STORE_wmask;

   // aluWr starts computation (shifts) in the ALU.
   assign aluWr = state[EXECUTE1_bit] & isALU;

   wire jumpToPCplusImm = isJAL | (isBranch & predicate);
`ifdef NRV_IS_IO_ADDR  
   wire needToWait = isLoad | 
		     isStore  & `NRV_IS_IO_ADDR(mem_addr) | 
		     aluBusy;
`else
   wire needToWait = isLoad | isStore | aluBusy;   
`endif
   
   always @(posedge clk) begin
      if(!reset) begin
         state      <= WAIT_ALU_OR_MEM; // Just waiting for !mem_wbusy
         PC         <= RESET_ADDR[ADDR_WIDTH-1:0];
      end else

      // See note [1] at the end of this file.
      (* parallel_case *)
      case(1'b1)

        state[WAIT_INSTR_bit]: begin
           if(!mem_rbusy) begin // may be high when executing from SPI flash
              rs1 <= registerFile[mem_rdata[19:15]];
              rs2 <= registerFile[mem_rdata[24:20]];
              instr <= mem_rdata[31:2]; // Bits 0 and 1 are ignored (see
              state <= EXECUTE1;        // also the declaration of instr).
           end
        end

        state[EXECUTE1_bit]: begin
	   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
	   // Equivalent to:
	   //  PCplusImm <= PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
	   PCplusImm <= PC + ( instr[3] ? Jimm[ADDR_WIDTH-1:0] : 
			       instr[4] ? Uimm[ADDR_WIDTH-1:0] : 
			                  Bimm[ADDR_WIDTH-1:0] );

	   // JALR
	   rs1plusImm <= rs1[ADDR_WIDTH-1:0] + Iimm[ADDR_WIDTH-1:0];
	   
	   // testing instr[5] is equivalent to testing isStore in this context.
	   loadstore_addr <= rs1[ADDR_WIDTH-1:0] + 
 		     (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);
	   
	   state <= EXECUTE2;
	end
	
        state[EXECUTE2_bit]: begin
           PC <= isJALR          ? {rs1plusImm[ADDR_WIDTH-1:1],1'b0} : 
                 jumpToPCplusImm ? PCplusImm  :
                 PCplus4;
	   state <= needToWait ? WAIT_ALU_OR_MEM : FETCH_INSTR;
        end

        state[WAIT_ALU_OR_MEM_bit]: begin
           if(!aluBusy & !mem_rbusy & !mem_wbusy) state <= FETCH_INSTR;
        end

        default: begin // FETCH_INSTR
          state <= WAIT_INSTR;
        end
	
      endcase
   end

   /***************************************************************************/
   // Cycle counter
   /***************************************************************************/

   reg [31:0]  cycles;
   always @(posedge clk) cycles <= cycles + 1;

endmodule

/*****************************************************************************/
// Notes:
//
// [1] About the "reverse case" statement, also used in Claire Wolf's picorv32:
// It is just a cleaner way of writing a series of cascaded if() statements,
// To understand it, think about the case statement *in general* as follows:
// case (expr)
//       val_1: statement_1
//       val_2: statement_2
//   ... val_n: statement_n
// endcase
// The first statement_i such that expr == val_i is executed. 
// Now if expr is 1'b1:
// case (1'b1)
//       cond_1: statement_1
//       cond_2: statement_2
//   ... cond_n: statement_n
// endcase
// It is *exactly the same thing*, the first statement_i such that
// expr == cond_i is executed (that is, such that 1'b1 == cond_i,
// in other words, such that cond_i is true)
// More on this: 
//     https://stackoverflow.com/questions/15418636/case-statement-in-verilog
//
// [2] state uses 1-hot encoding (at any time, state has only one bit set to 1).
// It uses a larger number of bits (one bit per state), but often results in
// a both more compact (fewer LUTs) and faster state machine.

