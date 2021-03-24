/*******************************************************************/
// FemtoRV32, a minimalistic RISC-V RV32I core.
// This version: single VERILOG file, compact & understandable code.
//
// Bruno Levy, May-June 2020
// Matthias Koch, March 2021
/*******************************************************************/

`include "utils.v"

module FemtoRV32(
   input          clk,

   output reg [31:0] mem_addr,  // address bus
   output     [31:0] mem_wdata, // data to be written
   output      [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input      [31:0] mem_rdata, // input lines for both data and instr
   output            mem_rstrb, // active to initiate memory read (used by IO)
   input             mem_rbusy, // asserted if memory is busy reading value
   input             mem_wbusy, // asserted if memory is busy writing value

   input             reset,     // set to 0 to reset the processor
   output            error      // always 0 in this version (does not check for errors)
);

   parameter RESET_ADDR       = `NRV_RESET_ADDR; // address the processor jumps to on reset
   parameter ADDR_WIDTH       = 24;              // ignored in this version
   parameter USE_MINI_DECODER = 1'b0;            // ignored in this version
   assign error = 1'b0;                          // this version does not check for invalid instr

   /***************************************************************************/
   // Instruction decoding.
   /***************************************************************************/

   // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction stored in reg instr[31:0]
   // Reference: Table page 104 of:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

   // The destination and source registers
   wire [4:0] rd  = instr[11:7];
   wire [4:0] rs1 = instr[19:15];
   wire [4:0] rs2 = instr[24:20];
   
   // The ALU function
   wire [2:0] funct3 = instr[14:12];
   
   // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm = {    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

   // base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:2] == 5'b00000); 
   wire isALUimm  =  (instr[6:2] == 5'b00100); 
   wire isAUIPC   =  (instr[6:2] == 5'b00101); 
   wire isStore   =  (instr[6:2] == 5'b01000); 
   wire isALUreg  =  (instr[6:2] == 5'b01100); 
   wire isLUI     =  (instr[6:2] == 5'b01101); 
   wire isBranch  =  (instr[6:2] == 5'b11000); 
   wire isJALR    =  (instr[6:2] == 5'b11001); 
   wire isJAL     =  (instr[6:2] == 5'b11011);
`ifdef NRV_COUNTERS	          
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); 
`endif
   
   /***************************************************************************/
   // The register file.
   /***************************************************************************/
   
   // At each cycle, reads two registers: rs1 -> rs1Data, rs2 -> rs2Data
   //                     and writes one: rd <- writeBackData
   // Notes:
   // - rs1Data and rs2Data are available at next cycle
   // - yosys is super-smart, and automagically duplicates the register file 
   //   in two BRAMs to be able to read two different registers in a single cycle.
   
   reg [31:0] rs1Data;
   reg [31:0] rs2Data;
   reg [31:0] registerFile [31:0];

   always @(posedge clk) begin
     rs1Data <= registerFile[rs1];
     rs2Data <= registerFile[rs2];
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
   //    ALUreg, Branch:     rs2                      (equivalent to isStore ? Simm : Iimm)
   //    Store:              Simm                                      |
   //    ALUimm, Load, JALR: Iimm                                      v
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2Data : (instr[6:5] == 2'b01 ? Simm : Iimm);

   reg [31:0] aluOut = aluReg; // The output of the ALU (wired to the ALU register)
   reg [31:0] aluReg;          // The internal register of the ALU, used by shift.
   reg [4:0]  aluShamt = 0;    // Current shift amount.

   wire aluBusy = |aluShamt;   // ALU is busy if shift amount is non-zero.
   wire aluWr;                 // ALU write strobe, starts computation.

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
   // - instr[30] is 1 for SRA (do sign extension) and 0 for SRL
   always @(posedge clk) begin
      if(aluWr) begin
         case(funct3) 
            3'b000: aluReg = instr[30] & instr[5] ? aluMinus[31:0] : aluPlus;  // ADD/SUB
            3'b010: aluReg = {31'b0, LT} ;                                     // SLT
            3'b011: aluReg = {31'b0, LTU};                                     // SLTU
            3'b100: aluReg = aluIn1 ^ aluIn2;                                  // XOR
            3'b110: aluReg = aluIn1 | aluIn2;                                  // OR
            3'b111: aluReg = aluIn1 & aluIn2;                                  // AND
            3'b001, 3'b101: begin aluReg = aluIn1; aluShamt = aluIn2[4:0]; end // SLL, SRA, SRL
         endcase
      end else begin
	 // Shift (multi-cycle)
         if (|aluShamt) begin
            aluShamt <= aluShamt - 1;
            case(funct3)
               3'b001: aluReg <= aluReg << 1;                             // SLL
               3'b101: aluReg <= instr[30] ? {aluReg[31], aluReg[31:1]} : // SRA
                                             {1'b0,       aluReg[31:1]} ; // SRL
            endcase
         end
      end
   end

   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   reg predicate; 
   always @(*) begin
      case(funct3)
        3'b000: predicate =  EQ;  // BEQ
        3'b001: predicate = !EQ;  // BNE
        3'b100: predicate =  LT;  // BLT
        3'b101: predicate = !LT;  // BGE
        3'b110: predicate =  LTU; // BLTU
        3'b111: predicate = !LTU; // BGEU
       default: predicate = 1'bx; // don't care...
      endcase
   end

   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [31:0] PC;         // The program counter.
   reg  [31:0] instr;      // Latched instruction.

`ifdef NRV_COUNTERS	       
   reg [31:0]  cycles;     // Cycle counter
`endif
   
   wire [31:0] PCplus4      = PC + 4;
   
   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to branchtarget = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
   wire [31:0] branchTarget = PC + (instr[3] ? Jimm : instr[4] ? Uimm : Bimm);

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
`ifdef NRV_COUNTERS	       
      (isSYSTEM            ? cycles       : 32'b0) |  // SYSTEM
`endif	       
      (isLUI               ? Uimm         : 32'b0) |  // LUI
      (isALUimm | isALUreg ? aluOut       : 32'b0) |  // ALU reg reg and ALU reg imm
      (isAUIPC             ? branchTarget : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? PCplus4      : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data    : 32'b0);   // Load

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // Circuitry that does unaligned word and byte load/store, based on:
   // - funct3[1:0]:        00->byte 01->halfword 10->word
   // - funct3[2]:          0->sign expansion   1->no sign expansion

   wire mem_byteAccess     =  funct3[1:0] == 2'b00;
   wire mem_halfwordAccess =  funct3[1:0] == 2'b01;

   // LOAD
   // mem_address[1:0]: indicates which byte/halfword is accessed

   wire LOAD_signedAccess   = !funct3[2];

   wire LOAD_sign = LOAD_signedAccess & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;
   
   wire [15:0] LOAD_halfword = mem_addr[1] ? mem_rdata[31:16]    : mem_rdata[15:0];
   wire  [7:0] LOAD_byte     = mem_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE
   // aluPlus[1:0]: indicates which byte/halfword is accessed (address = ALU output)
   
   assign mem_wdata[ 7: 0] =              rs2Data[7:0];
   assign mem_wdata[15: 8] = aluPlus[0] ? rs2Data[7:0] :                              rs2Data[15: 8];
   assign mem_wdata[23:16] = aluPlus[1] ? rs2Data[7:0] :                              rs2Data[23:16];
   assign mem_wdata[31:24] = aluPlus[0] ? rs2Data[7:0] : aluPlus[1] ? rs2Data[15:8] : rs2Data[31:24];

   wire [3:0] mem_wmask_store =
       mem_byteAccess ? (aluPlus[1] ? (aluPlus[0] ? 4'b1000 : 4'b0100) :   (aluPlus[0] ? 4'b0010 : 4'b0001) ) :
   mem_halfwordAccess ? (aluPlus[1] ?               4'b1100            :                 4'b0011            ) :
                                                    4'b1111;

   /*************************************************************************/
   // And, last but not least, the state machine.
   /*************************************************************************/

   reg [7:0] state;

   // The eight states, using 1-hot encoding (see note [2] at the end of this file).

   localparam FETCH_INSTR          = 8'b00000001;
   localparam WAIT_INSTR           = 8'b00000010;
   localparam FETCH_REGS           = 8'b00000100;
   localparam EXECUTE              = 8'b00001000;
   localparam LOAD                 = 8'b00010000;
   localparam WAIT_ALU_OR_DATA     = 8'b00100000;
   localparam STORE                = 8'b01000000;
   localparam WAIT_IO_STORE        = 8'b10000000;

   localparam FETCH_INSTR_bit          = 0;
   localparam WAIT_INSTR_bit           = 1;
   localparam FETCH_REGS_bit           = 2;
   localparam EXECUTE_bit              = 3;
   localparam LOAD_bit                 = 4;
   localparam WAIT_ALU_OR_DATA_bit     = 5;
   localparam STORE_bit                = 6;
   localparam WAIT_IO_STORE_bit        = 7;

   // The internal signals that are determined combinatorially from
   // state and other signals.

   // register write-back enable.
   wire writeBack = (state[EXECUTE_bit] & ~(isBranch | isStore)) |
                     state[WAIT_ALU_OR_DATA_bit];

   // The memory-read signal.
   assign mem_rstrb = state[LOAD_bit] | state[FETCH_INSTR_bit];
   
   // The mask for memory-write.
   assign mem_wmask = state[STORE_bit] ? mem_wmask_store : 4'b0000;

   // aluWr starts computation in the ALU.
   assign aluWr = state[EXECUTE_bit] & (isALUimm | isALUreg);

   wire takeBranch = isJAL | (isBranch & predicate);

   always @(posedge clk) begin
      if(!reset) begin
         state      <= WAIT_IO_STORE; // Just waiting for !mem_wbusy
         PC         <= RESET_ADDR;
      end else

      // See note [1] at the end of this file.
      (* parallel_case, full_case *)
      case(1'b1)

        // *********************************************************************
        // Handles jump/branch, or transitions to waitALU, load, store

        state[EXECUTE_bit]: begin

           PC       <= isJALR ? aluPlus :
                       (takeBranch ? branchTarget : PCplus4);

           mem_addr <= isJALR | isALUimm | isALUreg | isStore | isLoad ? aluPlus :
                       (takeBranch ? branchTarget : PCplus4);

	   // Transitions from EXECUTE to WAIT_ALU_OR_DATA, STORE, LOAD, and FETCH_INSTR,
	   // See note [3] at the end of this file.
           state <= {
		 1'b0,                                // WAIT_IO_STORE
                 isStore,                             // STORE
                 isALUimm|isALUreg,                   // WAIT_ALU_OR_DATA
                 isLoad,                              // LOAD
                 1'b0,                                // EXECUTE
                 1'b0,                                // FETCH_REGS
                 1'b0,                                // WAIT_INSTR
                 !(isStore|isALUimm|isALUreg|isLoad)  // FETCH_INSTR
           };
        end

        // *********************************************************************
        // Additional wait state for instruction fetch.

        state[WAIT_INSTR_bit]: begin
           if(!mem_rbusy) begin // rbusy may be high when executing from SPI flash
              instr <= mem_rdata;
              state <= FETCH_REGS;
           end
        end

        // *********************************************************************
        // Used by LOAD and by multi-cycle ALU instr (shifts and RV32M ops), writeback from ALU or memory
        //    also waits from data from IO (listens to mem_rbusy)

        state[WAIT_ALU_OR_DATA_bit] | state[WAIT_IO_STORE_bit]: begin
           if(!aluBusy & !mem_rbusy & !mem_wbusy) begin
              mem_addr <= PC;
              state <= FETCH_INSTR;
           end
        end

        // *********************************************************************
        // All the remaining transitions. See note [3] at the end of this file.

        default: begin
          state <= {
	      state[STORE_bit],       // STORE           -> WAIT_IO_STORE
	      1'b0,                   // *no transition* -> STORE (already done from EXECUTE)
	      state[LOAD_bit],        // LOAD            -> WAIT_ALU_OR_DATA
	      1'b0,                   // *no transition* -> LOAD (already done from EXECUTE)
	      state[FETCH_REGS_bit],  // FETCH_REGS      -> EXECUTE
	      1'b0,                   // *no transition* -> FETCH_REGS (already done from WAIT_INSTR)
	      state[FETCH_INSTR_bit], // FETCH_INSTR     -> WAIT_INSTR
	      1'b0                    // *no transition* -> FETCH_INSTR (already done from EXECUTE, 
	  };                          //                          WAIT_ALU_OR_DATA and WAIT_IO_STORE)
        end

        // *********************************************************************

      endcase
   end

   /***************************************************************************/
   // Cycle counter
   /***************************************************************************/
`ifdef NRV_COUNTERS	             
   always @(posedge clk) cycles <= cycles + 1;
`endif
   
endmodule

/*****************************************************************************/
// Notes:
//
// [1] About the "reverse case" statement, also used in Claire Wolf's picorv32:
// It is just a cleaner way of writing a series of cascaded if() statements,
// see: https://stackoverflow.com/questions/15418636/case-statement-in-verilog
//
// [2] state uses 1-hot encoding (at any time, state has only one bit set to 1).
// It uses a larger number of bits (one bit per state), but often results in
// a both more compact (fewer LUTs) and faster state machine.
//
// [3] In addition, using 1-hot encoding, it is possible to express a set of 
// transitions in a single statement, by setting each bit of state according 
// to the previous value of other bits of state (and optionally other conditions).
