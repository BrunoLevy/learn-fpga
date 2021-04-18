/**************************************************************************/
// FemtoRV32-Quark, an elementary RISC-V RV32I core.
// Mission statement: a single VERILOG file, compact & understandable code
//                    that fits in the smallest FPGAs (IceStick)
//                    200 lines of code, 400 lines counting comments
// Parameters:
//    RESET_ADDR initial value of PC (default = 0)
//    ADDR_WIDTH number of bits in internal address bus (default = 24)
//
// Macros: 
//    optionally one may define NRV_IS_IO_ADDR(addr), that is supposed to:
//              evaluate to 1 if addr is in mapped IO space, 
//              evaluate to 0 otherwise
//    (additional wait states are used when in IO space).
//    If left undefined, wait states are always used.
//
//    NRV_COUNTER_WIDTH may be defined to reduce the number of bits used
//    by the ticks counter. If not defined, a 32-bits counter is generated.
//    (reducing its width may be useful for space-constrained designs).
//
//    NRV_TWOLEVEL_SHIFTER may be defined to make shift operations faster
//    (uses a two-level shifter inspired by picorv32).
//
// Bruno Levy & Matthias Koch, 2020-2021
/**************************************************************************/

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

   parameter RESET_ADDR       = 0;  // the address that the processor jumps to on reset
   parameter ADDR_WIDTH       = 24; // number of bits in address registers

   localparam ADDR_PAD= {(32-ADDR_WIDTH){1'b0}}; // 32-bits padding for addresses
   reg [ADDR_WIDTH-1:0] addr_reg;                // The internal register plugged to mem_addr
   assign mem_addr = {ADDR_PAD,addr_reg};

   /***************************************************************************/
   // Instruction decoding.
   /***************************************************************************/

   // Extracts rd,rs1,rs2,funct3Equals,imm and opcode from instruction stored in reg instr[31:0]
   // Reference: Table page 104 of:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

   // The destination register
   wire [4:0] rd  = instr[11:7];

   // The ALU function
   wire [2:0] funct3 = instr[14:12];

   // Decoded ALU function as 1-hot: funct3Equals[i] <=> funct3 == i
   // (using it reduces overall LUT count)
   (* onehot *)
   wire [7:0] funct3Equals = 8'b00000001 << funct3;  
   
   // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm = {    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   /* verilator lint_off UNUSED */ // MSBs of Bimm and Jimm are not used if ADDR_WIDTH is less than 32
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
   /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   // We do not test for erroneous opcodes (and the two LSBs are ignored)
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

   reg [31:0] rs1Data;
   reg [31:0] rs2Data;
   reg [31:0] registerFile [31:0];

   always @(posedge clk) begin
     if (writeBack)
       if (rd != 0)
         registerFile[rd] <= writeBackData;
   end

   /***************************************************************************/
   // The ALU.
   /***************************************************************************/

   // Operands are given in aluIn1 and aluIn2. They are written when aluWr is set.
   // Result is available in aluOut from next cycle as soon as aluBusy is zero.
   // Other signals (combinatorially wired):
   //   aluPlus (aluIn1 + aluIn2)
   //   EQ      (aluIn1 == aluIn2)
   //   LT      (signed aluIn1 < signed aluIn2)
   //   LTU     (unsigned aluIn1 < unsigned aluIn2)

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1Data;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    Store:              Simm
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2Data : (isStore ? Simm : Iimm);

   reg  [31:0] aluReg;          // The internal register of the ALU, used by shift.
   reg  [4:0]  aluShamt;        // Current shift amount.

   wire aluBusy = |aluShamt;    // ALU is busy if shift amount is non-zero.
   wire aluWr;                  // ALU write strobe, starts computation.

   // The adder is used by both arithmetic instructions and address computation.
   wire [31:0] aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   // Notes:
   // - instr[30] is 1 for SUB and 0 for ADD
   // - for SUB, need to test also instr[5] (1 for ADD/SUB, 0 for ADDI, because ADDI imm uses bit 30 !)
   wire [31:0] aluOut =
      (funct3Equals[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) | // ADD/SUB
      (funct3Equals[2]  ? {31'b0, LT}                                     : 32'b0) | // SLT
      (funct3Equals[3]  ? {31'b0, LTU}                                    : 32'b0) | // SLTU
      (funct3Equals[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) | // XOR
      (funct3Equals[6]  ? aluIn1 | aluIn2                                 : 32'b0) | // OR
      (funct3Equals[7]  ? aluIn1 & aluIn2                                 : 32'b0) | // AND
      (functIsShift     ? aluReg                                          : 32'b0) ; // SLL, SRA, SRL

   wire functIsShift = funct3Equals[1] | funct3Equals[5];
   wire srl_sra = instr[30]; // asserted if shift is arithmetic (then we do sign expansion)
   
   always @(posedge clk) begin
      if(aluWr) begin
        if (functIsShift) begin 
	   aluReg <= aluIn1; 
	   aluShamt <= aluIn2[4:0]; 
	end 
      end 

`ifdef NRV_TWOLEVEL_SHIFTER
      else if(|aluShamt[3:2]) begin // If shift amount is greater than 4, shift by 4
         aluShamt <= aluShamt - 4;
	 aluReg <= funct3[2] ? {{4{srl_sra & aluReg[31]}}, aluReg[31:4]} : aluReg << 4 ;	    
      end  else
`endif
	
      if (|aluShamt) begin
         // Compact form of:
         //   funct3=101 &  instr[0] -> SRA  (aluReg <= {aluReg[31], aluReg[31:1]})
         //   funct3=101 & !instr[0] -> SRL  (aluReg <= {1'b0,       aluReg[31:1]})
         //   funct3=001             -> SLL  (aluReg <= aluReg << 1)
         aluShamt <= aluShamt - 1;
	 aluReg <= funct3[2] ? {srl_sra & aluReg[31], aluReg[31:1]} : aluReg << 1 ;
      end
      
   end

   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   wire predicate =
        funct3Equals[0] &  EQ  | // BEQ
        funct3Equals[1] & !EQ  | // BNE
        funct3Equals[4] &  LT  | // BLT
        funct3Equals[5] & !LT  | // BGE
        funct3Equals[6] &  LTU | // BLTU
        funct3Equals[7] & !LTU ; // BGEU

   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instruction set).

   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
   wire [ADDR_WIDTH-1:0] PCplusImm = PC + (instr[3] ? Jimm[ADDR_WIDTH-1:0] : instr[4] ? Uimm[ADDR_WIDTH-1:0] : Bimm[ADDR_WIDTH-1:0]);

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
      /* verilator lint_off WIDTH */	       	       
      (isSYSTEM            ? cycles               : 32'b0) |  // SYSTEM
      /* verilator lint_on WIDTH */	       	       	       
      (isLUI               ? Uimm                 : 32'b0) |  // LUI
      (isALU               ? aluOut               : 32'b0) |  // ALU reg reg and ALU reg imm
      (isAUIPC             ? {ADDR_PAD,PCplusImm} : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? {ADDR_PAD,PCplus4  } : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data            : 32'b0);   // Load

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned word
   // and byte load/store, based on:
   // - funct3[1:0]:   00->byte 01->halfword 10->word
   // - addr_reg[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     = instr[13:12] == 2'b00; // funct3[0] | funct3[4]; // funct3[1:0] == 2'b00;
   wire mem_halfwordAccess = instr[13:12] == 2'b01; // funct3[1] | funct3[5]; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2]:        0->sign expansion   1->no sign expansion

   wire LOAD_sign = !instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   wire [15:0] LOAD_halfword = addr_reg[1] ? mem_rdata[31:16]    : mem_rdata[15:0];
   wire  [7:0] LOAD_byte     = addr_reg[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE

   assign mem_wdata[ 7: 0] =               rs2Data[7:0];
   assign mem_wdata[15: 8] = addr_reg[0] ? rs2Data[7:0] :                               rs2Data[15: 8];
   assign mem_wdata[23:16] = addr_reg[1] ? rs2Data[7:0] :                               rs2Data[23:16];
   assign mem_wdata[31:24] = addr_reg[0] ? rs2Data[7:0] : addr_reg[1] ? rs2Data[15:8] : rs2Data[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword (depending on addr_reg[1])
   //    0001, 0010, 0100 or 1000 if writing a byte     (depending on addr_reg[1:0])

   wire [3:0] STORE_wmask =
       mem_byteAccess ? (addr_reg[1] ? (addr_reg[0] ? 4'b1000 : 4'b0100) :   (addr_reg[0] ? 4'b0010 : 4'b0001) ) :
   mem_halfwordAccess ? (addr_reg[1] ?                4'b1100            :                  4'b0011            ) :
                                                      4'b1111;

   /*************************************************************************/
   // And, last but not least, the state machine.
   /*************************************************************************/
   // The states, using 1-hot encoding (see note [2] at the end of this file).

   localparam FETCH_INSTR_bit     = 0;
   localparam WAIT_INSTR_bit      = 1;
   localparam EXECUTE_bit         = 2;
   localparam LOAD_bit            = 3;
   localparam STORE_bit           = 4;   
   localparam WAIT_ALU_OR_MEM_bit = 5;
   localparam MAX_STATE           = 5;

   localparam FETCH_INSTR     = 1 << FETCH_INSTR_bit;
   localparam WAIT_INSTR      = 1 << WAIT_INSTR_bit;
   localparam EXECUTE         = 1 << EXECUTE_bit;
   localparam LOAD            = 1 << LOAD_bit;
   localparam WAIT_ALU_OR_MEM = 1 << WAIT_ALU_OR_MEM_bit;
   localparam STORE           = 1 << STORE_bit;

   (* onehot *)
   reg [MAX_STATE:0] state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.

   // register write-back enable.
   wire  writeBack = ~(isBranch | isStore ) & (state[EXECUTE_bit] | state[WAIT_ALU_OR_MEM_bit]);

   // The memory-read signal.
   assign mem_rstrb = state[LOAD_bit] | state[FETCH_INSTR_bit];

   // The mask for memory-write.
   assign mem_wmask = {4{state[STORE_bit]}} & STORE_wmask;

   // aluWr starts computation in the ALU.
   assign aluWr = state[EXECUTE_bit] & isALU;

   wire jumpToPCplusImm = isJAL | (isBranch & predicate);

   always @(posedge clk) begin
      if(!reset) begin
         state      <= WAIT_ALU_OR_MEM; // Just waiting for !mem_wbusy
         PC         <= RESET_ADDR[ADDR_WIDTH-1:0];
      end else

      // See note [1] at the end of this file.
      (* parallel_case, full_case *)
      case(1'b1)

        // *********************************************************************	
	state[FETCH_INSTR_bit]: begin
	   state <= WAIT_INSTR;
	end
	
        // *********************************************************************
        state[WAIT_INSTR_bit]: begin
           if(!mem_rbusy) begin // rbusy may be high when executing from SPI flash
              rs1Data <= registerFile[mem_rdata[19:15]];
              rs2Data <= registerFile[mem_rdata[24:20]];
              instr <= mem_rdata[31:2]; // Note that bits 0 and 1 are ignored (see
              state <= EXECUTE;         //          also the declaration of instr).
           end
        end
	
        // *********************************************************************
        state[EXECUTE_bit]: begin

           // Prepare next PC
           PC <= isJALR          ? aluPlus[ADDR_WIDTH-1:0] :
                 jumpToPCplusImm ? PCplusImm :
                 PCplus4;

           // Prepare address for:
           //  next instruction fetch: PCplusImm (taken branch, JAL), aluPlus (JALR), PCplus4 (all other instr.)
           //  load/store: aluPlus
           addr_reg <= isJALR | isStore | isLoad ?   aluPlus[ADDR_WIDTH-1:0] :
                       jumpToPCplusImm           ? PCplusImm[ADDR_WIDTH-1:0] :
                       PCplus4;

           state <= isLoad                 ? LOAD             : 
		    isStore                ? STORE            : 
		    (isALU & functIsShift) ? WAIT_ALU_OR_MEM  : 
		                             FETCH_INSTR      ;
        end 
	
        // *********************************************************************
        state[LOAD_bit]: begin
	   state <= WAIT_ALU_OR_MEM;
	end
	
        // *********************************************************************
        state[STORE_bit]: begin
`ifdef NRV_IS_IO_ADDR
	   state <= `NRV_IS_IO_ADDR(addr_reg) ? WAIT_ALU_OR_MEM : FETCH_INSTR;
	   addr_reg <= PC;
`else
	   state <= WAIT_ALU_OR_MEM;
`endif	   
        end
	
        // *********************************************************************
        state[WAIT_ALU_OR_MEM_bit]: begin
           // Used by LOAD,STORE and by multi-cycle ALU instr (shifts and RV32M ops),
           // writeback from ALU or memory, also waits from data from IO
           // (listens to mem_rbusy and mem_wbusy)
           if(!aluBusy & !mem_rbusy & !mem_wbusy) begin
              addr_reg <= PC;
              state <= FETCH_INSTR;
           end
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
// The first statement_i such that expr == val_i is executed. Now if expr is 1'b1:
// case (1'b1)
//       cond_1: statement_1
//       cond_2: statement_2
//   ... cond_n: statement_n
// endcase
// It is *exactly the same thing*, the first statement_i such that
// expr == cond_i is executed (that is, such that 1'b1 == cond_i,
// in other words, such that cond_i is true)
// More on this: https://stackoverflow.com/questions/15418636/case-statement-in-verilog
//
// [2] state uses 1-hot encoding (at any time, state has only one bit set to 1).
// It uses a larger number of bits (one bit per state), but often results in
// a both more compact (fewer LUTs) and faster state machine.

