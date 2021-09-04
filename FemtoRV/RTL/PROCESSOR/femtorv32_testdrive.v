/******************************************************************************/
// TestDrive: morphing tachyon into a RV32IMF core, trying to 
// preserve maxfreq at each step.
// Step 0: Tachyon       valid. fmax: 115-120 MHz  exp. fmax: 135-140 MHz
// Step 1: Barrel shft   valid. fmax: 110-115 MHz  exp. fmax: 130-135 MHz
// Step 2: RV32M         valid. fmax: 90      MHz  exp. fmax: 115     MHz
/******************************************************************************/

// Firmware generation flags for this processor
`define NRV_ARCH     "rv32im"
`define NRV_ABI      "ilp32"
`define NRV_OPTIMIZE "-O3"

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


   // Flip a 32 bit word. Used by the shifter (a single shifter for
   // left and right shifts, saves silicium !)
   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

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

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

   wire aluWr;               // ALU write strobe

   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   /***************************************************************************/

   // Use the same shifter both for left and right shifts by 
   // applying bit reversal

   wire [31:0] shifter_in = funct3Is[1] ? flip32(aluIn1) : aluIn1;
   
   /* verilator lint_off WIDTH */
   wire [31:0] shifter = 
               $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] leftshift = flip32(shifter);
   
   /***************************************************************************/

   // funct3: 1->MULH, 2->MULHSU  3->MULHU
   wire isMULH   = funct3Is[1];
   wire isMULHSU = funct3Is[2];

   wire sign1 = aluIn1[31] &  isMULH;
   wire sign2 = aluIn2[31] & (isMULH | isMULHSU);

   wire signed [32:0] signed1 = {sign1, aluIn1};
   wire signed [32:0] signed2 = {sign2, aluIn2};
   wire signed [63:0] multiply = signed1 * signed2;

   /***************************************************************************/

   // Notes:
   // - instr[30] is 1 for SUB and 0 for ADD
   // - for SUB, need to test also instr[5] to discriminate ADDI:
   //    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
   // - instr[30] is 1 for SRA (do sign extension) and 0 for SRL

   wire [31:0] alu_base =
     (funct3Is[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[1]  ? leftshift                                       : 32'b0) |
     (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
     (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
     (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
     (funct3Is[5]  ? shifter                                         : 32'b0) |
     (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
     (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) ;

   // funct3: 0->MUL 1->MULH 2->MULHSU 3->MULHU
   //         4->DIV 5->DIVU 6->REM    7->REMU
   
   wire [31:0] alu_mul = funct3Is[0] ? multiply[31: 0]   // 0:MUL
                                     : multiply[63:32] ; // 1:MULH, 2:MULHSU, 3:MULHU

   wire [31:0] alu_div = instr[13] ? (div_sign ? -dividendN : dividendN) 
    	                           : (div_sign ? -quotientN : quotientN);
   

   wire aluBusy = |quotient_msk ; // ALU is busy if division is in progress.
   reg [31:0]  aluOut;

   wire funcM     = instr[25];
   wire isDivide  = instr[14];
   
   always @(posedge clk) begin
	 aluOut <=  (isALUreg & funcM) ? (isDivide ? alu_div : alu_mul) : alu_base;
   end


   /***************************************************************************/
   // Implementation of DIV/REM instructions, highly inspired by PicoRV32

   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;

   wire divstep_do = divisor <= {31'b0, dividend};

   wire [31:0] dividendN     = divstep_do ? dividend - divisor[31:0] : dividend;
   wire [31:0] quotientN     = divstep_do ? quotient | quotient_msk  : quotient;

   wire div_sign = ~instr[12] & (instr[13] ? aluIn1[31] : 
                    (aluIn1[31] != aluIn2[31]) & |aluIn2);

   always @(posedge clk) begin
      if (isALUreg & funcM & isDivide & aluWr) begin
	 dividend <=   ~instr[12] & aluIn1[31] ? -aluIn1 : aluIn1;
	 divisor  <= {(~instr[12] & aluIn2[31] ? -aluIn2 : aluIn2), 31'b0};
	 quotient <= 0;
	 quotient_msk <= 1 << 31;
      end else begin
	 dividend     <= dividendN;
	 divisor      <= divisor >> 1;
	 quotient     <= quotientN;
	 quotient_msk <= quotient_msk >> 1;
      end
   end
      
   reg  [31:0] divResult;
   always @(posedge clk) divResult <= instr[13] ? dividendN : quotientN;
 
   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   wire predicate_ =
        funct3Is[0] &  EQ  | // BEQ
        funct3Is[1] & !EQ  | // BNE
        funct3Is[4] &  LT  | // BLT
        funct3Is[5] & !LT  | // BGE
        funct3Is[6] &  LTU | // BLTU
        funct3Is[7] & !LTU ; // BGEU

   reg 	predicate;
   
   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instr set).

   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   reg [ADDR_WIDTH-1:0]  PCplusImm;

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

	   // testing instr[5] is equivalent to testing isStore in this context.
	   loadstore_addr <= rs1[ADDR_WIDTH-1:0] + 
 		     (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);
	   
	   predicate <= predicate_;
	   state <= EXECUTE2;
	end
	
        state[EXECUTE2_bit]: begin
           PC <= isJALR          ? {aluPlus[ADDR_WIDTH-1:1],1'b0} :
                 jumpToPCplusImm ? PCplusImm :
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

`ifdef NRV_COUNTER_WIDTH
   reg [`NRV_COUNTER_WIDTH-1:0]  cycles;   
`else   
   reg [31:0]  cycles;
`endif   
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

