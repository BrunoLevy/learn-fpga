/*****************************************************************************/
// FemtoRV32, a minimalistic RISC-V RV32I core.
// This version: The fast "Quark":
//       single VERILOG file, compact & understandable code.
//       (200 lines of code, 400 lines counting comments)
//
// Comparison with the "Quark": one additional ALU state, latched
//   predicates (validates at 60 MHz on the IceStick)
//
// Reset address can be defined using NRV_RESET_ADDR (default is 0).
//
// If NRV_COUNTER_WIDTH is defined, it generates a cycles counter
//   (use `define NRV_COUNTER_WIDTH 32 for a 32-bits counter)
//   It can be read using the RDCYCLES instruction.
//
// The ADDR_WIDTH parameter lets you define the width of the internal
//   address bus (and address computation logic). 
//
// If NRV_TWOLEVEL_SHIFTER is defined, shifts are much faster (without it
//  they can take up to 32 cycles !). But it eats up some LUTs (no free lunch)
//
// If NRV_LATCH_RECOGNIZERS is defined, then signals that recognize
//   instructions are latched (may increase maxfreq / decrease LUT
//   count but depends on yosys version).
//
// Bruno Levy, May-June 2020
// Matthias Koch, March 2021
/****************************************************************************/

`ifndef NRV_RESET_ADDR
 `define NRV_RESET_ADDR 32'b0
`endif

// Tests whether a given address is in mapped devices space. If asserted,
// reading/writing needs to wait for mem_rbusy/mem_wbusy to go low.
`define NRV_IS_IO_ADDR(addr) |addr[23:22]

module FemtoRV32(
   input clk,

   output [31:0] mem_addr,  // address bus
   output [31:0] mem_wdata, // data to be written
   output  [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input  [31:0] mem_rdata, // input lines for both data and instr
   output        mem_rstrb, // active to initiate memory read (used by IO)
   input         mem_rbusy, // asserted if memory is busy reading value
   input         mem_wbusy, // asserted if memory is busy writing value

   input         reset,     // set to 0 to reset the processor
   output        error      // always 0 in this version (does not check for errors)
);

   parameter RESET_ADDR       = `NRV_RESET_ADDR; // the address that the processor jumps to on reset
   parameter ADDR_WIDTH       = 24;              // ignored in this version
   assign error = 1'b0;                          // this version does not check for invalid instr

   parameter ADDR_PAD= {(32-ADDR_WIDTH){1'b0}};  // 32-bits padding for addresses
   reg [ADDR_WIDTH-1:0] addr_reg;                // The internal register plugged to mem_addr
   assign mem_addr = {ADDR_PAD,addr_reg};
   
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

   wire [4:0] rs1_ = mem_rdata[19:15];
   wire [4:0] rs2_ = mem_rdata[24:20];
   
   // The ALU function
   wire [2:0] funct3 = instr[14:12];

   // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm = {    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

   // Base RISC-V (RV32I) has only 10 different instructions !
   // Note: maxfreq may be sometimes improved by latching the following 
   // signals (not done here because it makes the code less legible).
   
   wire isLoad    =  (instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isStore   =  (instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   wire isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
   wire isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
   wire isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm

`ifdef NRV_COUNTER_WIDTH
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- cycles
`endif

   wire isALU = isALUimm | isALUreg;
   
   /***************************************************************************/
   // The register file.
   /***************************************************************************/
   
   // At each cycle, reads two registers: rs1 -> rs1Data, rs2 -> rs2Data
   //                     and writes one: rd <- writeBackData
   // Notes:
   // - rs1Data and rs2Data are available after a "data in flight" cycle.
   // - yosys is super-smart, and automagically duplicates the register file 
   //   in two BRAMs to be able to read two different registers in a single cycle.
   
   reg [31:0] rs1Data;
   reg [31:0] rs2Data;
   reg [31:0] registerFile [31:0];

   always @(posedge clk) begin
     if (writeBack && rd != 0) begin
         registerFile[rd] <= writeBackData;
     end
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
   
   // ALU inputs and outputs.
   wire [31:0] aluIn1 = rs1Data;
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2Data : Iimm;
   wire [31:0] aluOut = aluReg; // The output of the ALU (wired to the ALU register)
   reg predicate;
   
   reg [31:0] aluReg;           // The internal register of the ALU, used by shift.
   reg [4:0]  aluShamt;         // Current shift amount.

   wire aluBusy = |aluShamt;   // ALU is busy if shift amount is non-zero.
   wire aluWr;                 // ALU write strobe, starts computation.

   wire [31:0] aluPlus = aluIn1 + aluIn2; // The adder of the ALU
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
            3'b000: aluReg <= instr[30] & instr[5] ? aluMinus[31:0] : aluPlus;   // ADD/SUB
            3'b010: aluReg <= {31'b0, LT} ;                                      // SLT
            3'b011: aluReg <= {31'b0, LTU};                                      // SLTU
            3'b100: aluReg <= aluIn1 ^ aluIn2;                                   // XOR
            3'b110: aluReg <= aluIn1 | aluIn2;                                   // OR
            3'b111: aluReg <= aluIn1 & aluIn2;                                   // AND
            3'b001, 3'b101: begin aluReg <= aluIn1; aluShamt <= aluIn2[4:0]; end // SLL, SRA, SRL
         endcase
      end else begin
	 // Shift (multi-cycle)
`ifdef NRV_TWOLEVEL_SHIFTER	 
	 if(|aluShamt[3:2]) begin
            aluShamt <= aluShamt - 4;
	    // Compact form of:
	    //   funct3=101 &  instr[30] -> SRA  (aluReg <= {{4{aluReg[31]}}, aluReg[31:4]})
	    //   funct3=101 & !instr[30] -> SRL  (aluReg <= { 4'b0000,        aluReg[31:4]})		      
            //   funct3=001              -> SLL  (aluReg <= aluReg << 4)
	    aluReg <= funct3[2] ? {{4{instr[30] & aluReg[31]}}, aluReg[31:4]} : aluReg << 4 ;	    
	 end else
`endif 	   
         if (|aluShamt) begin
            aluShamt <= aluShamt - 1;
	    // Compact form of:
	    //   funct3=101 &  instr[30] -> SRA  (aluReg <= {aluReg[31], aluReg[31:1]})
	    //   funct3=101 & !instr[30] -> SRL  (aluReg <= {1'b0,       aluReg[31:1]})		      
            //   funct3=001              -> SLL  (aluReg <= aluReg << 1)
	    aluReg <= funct3[2] ? {instr[30] & aluReg[31], aluReg[31:1]} : aluReg << 1 ;
         end
      end
   end

   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   always @(posedge clk) begin
      if(state[ADDR_AND_ALU_bit])
	case(funct3)
          3'b000: predicate <=  EQ;   // BEQ
          3'b001: predicate <= !EQ;   // BNE
          3'b100: predicate <=  LT;   // BLT
          3'b101: predicate <= !LT;   // BGE
          3'b110: predicate <=  LTU;  // BLTU
          3'b111: predicate <= !LTU;  // BGEU
          default: predicate <= 1'bx; // don't care...
	endcase
   end

   /***************************************************************************/
   // Program counter and address computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instruction set).

   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;

   // The address adder, that computes PC+imm / rs1+imm
   wire [ADDR_WIDTH-1:0] addrAdderIn1 = (isLoad | isStore | isJALR) ? rs1Data[ADDR_WIDTH-1:0] : PC;
   wire [ADDR_WIDTH-1:0] addrAdderIn2 = isJAL    ? Jimm[ADDR_WIDTH-1:0] :
			                isAUIPC  ? Uimm[ADDR_WIDTH-1:0] :
			                isStore  ? Simm[ADDR_WIDTH-1:0] :
			                isBranch ? Bimm[ADDR_WIDTH-1:0] :
			                           Iimm[ADDR_WIDTH-1:0] ; // LOAD and JALR
   
   reg [ADDR_WIDTH-1:0]  addrAdderOut;
   always @(posedge clk) begin
      if(state[ADDR_AND_ALU_bit])
	addrAdderOut <= addrAdderIn1 + addrAdderIn2;
   end
   
   /***************************************************************************/
   // Cycle counter
   /***************************************************************************/

`ifdef NRV_COUNTER_WIDTH	       
   reg [`NRV_COUNTER_WIDTH-1:0]  cycles;     // Cycle counter
`endif
   
   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
`ifdef NRV_COUNTER_WIDTH
      /* verilator lint_off WIDTH */	       
      (isSYSTEM            ? cycles       : 32'b0) |  // SYSTEM
      /* verilator lint_on WIDTH */	       	       
`endif	       
      (isLUI               ? Uimm                    : 32'b0) |  // LUI
      (isALU               ? aluOut                  : 32'b0) |  // ALU reg reg and ALU reg imm
      (isAUIPC             ? {ADDR_PAD,addrAdderOut} : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? {ADDR_PAD,PCplus4     } : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data               : 32'b0);   // Load

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this 
   // reason, we need some circuitry that does unaligned word 
   // and byte load/store, based on:
   // - funct3[1:0]:       00->byte 01->halfword 10->word
   // - mem_address[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     =  funct3[1:0] == 2'b00;
   wire mem_halfwordAccess =  funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2]:        0->sign expansion   1->no sign expansion
   
   wire LOAD_signedAccess   = !funct3[2];
   wire LOAD_sign = LOAD_signedAccess & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

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

   reg [7:0] state;

   // The eight states, using 1-hot encoding (see note [2] at the end of this file).

   localparam FETCH_INSTR     = 8'b00000001; // mem_addr was updated at previous cycle, instr is in flight
   localparam WAIT_INSTR      = 8'b00000010; // latch instr if available, else wait for it (if run from SPI)
   localparam FETCH_REGS      = 8'b00000100; // reg ids were updated at previous cycle, reg vals are in flight
   localparam EXECUTE         = 8'b00001000; // crossroads state
   localparam LOAD            = 8'b00010000; // mem_addr updated at previous cycle, data is in flight
   localparam WAIT_ALU_OR_MEM = 8'b00100000; // wait for ALU or mem transfer
   localparam STORE           = 8'b01000000; // mem_addr and data updated at previous cycle, mem_wmask is set
   localparam ADDR_AND_ALU    = 8'b10000000; // address computation (branch target, load, store) and start ALU

   localparam FETCH_INSTR_bit     = 0;
   localparam WAIT_INSTR_bit      = 1;
   localparam FETCH_REGS_bit      = 2;
   localparam EXECUTE_bit         = 3;
   localparam LOAD_bit            = 4;
   localparam WAIT_ALU_OR_MEM_bit = 5;
   localparam STORE_bit           = 6;
   localparam ADDR_AND_ALU_bit    = 7;   
    

   // The signals (internal and external) that are determined 
   // combinatorially from state and other signals.

   // register write-back enable.
   wire  writeBack = ~(isBranch | isStore ) & (state[EXECUTE_bit] | state[WAIT_ALU_OR_MEM_bit]);
   
   // The memory-read signal.
   assign mem_rstrb = state[LOAD_bit] | state[FETCH_INSTR_bit];
   
   // The mask for memory-write.
   assign mem_wmask = {4{state[STORE_bit]}} & STORE_wmask; 

   // aluWr starts computation in the ALU.
   assign aluWr = state[ADDR_AND_ALU_bit] & isALU;

   wire jumpOrTakeBranch = isJAL | isJALR | (isBranch & predicate);

   always @(posedge clk) begin
      if(!reset) begin
         state      <= WAIT_ALU_OR_MEM; // Just waiting for !mem_wbusy
         PC         <= RESET_ADDR[ADDR_WIDTH-1:0];
      end else

      // See note [1] at the end of this file.
      (* parallel_case, full_case *)
      case(1'b1)

        // *********************************************************************
        // Handles jump/branch, or transitions to waitALU, load, store

        state[EXECUTE_bit]: begin

	   // Prepare next PC
           PC <= jumpOrTakeBranch ? addrAdderOut : PCplus4;

	   // Prepare address for next instruction fetch: 
	   //    taken branch, JAL: PCplusImm  (addrAdderOut)
	   //    JALR, load, store: rs1plusImm (addrAdderOut)
	   //    All other instr  : PCplus4
           addr_reg <= isLoad | isStore | jumpOrTakeBranch ? addrAdderOut : PCplus4;
	   
	   // Transitions from EXECUTE to WAIT_ALU_OR_DATA, STORE, LOAD, and FETCH_INSTR,
	   // See note [3] at the end of this file.
           state <= {
		 1'b0,                                // ADDR_AND_ALU    
                 isStore,                             // STORE
                 aluBusy,                             // WAIT_ALU_OR_MEM
                 isLoad,                              // LOAD
                 1'b0,                                // EXECUTE
                 1'b0,                                // FETCH_REGS
                 1'b0,                                // WAIT_INSTR
                 !(isLoad|isStore|isALU) | (isALU & !aluBusy) // FETCH_INSTR
           };
        end

        // *********************************************************************
        // Additional wait state for instruction fetch.

        state[WAIT_INSTR_bit]: begin
           if(!mem_rbusy) begin // rbusy may be high when executing from SPI flash
              instr <= mem_rdata[31:2]; // Note that bits 0 and 1 are ignored (see
              state <= FETCH_REGS;      //          also the declaration of instr).
	      rs1Data <= registerFile[rs1_];
	      rs2Data <= registerFile[rs2_];
           end
        end

	// *********************************************************************
	// STORE: if the address is in mapped IO space, transition to wait state.
	
        state[STORE_bit]: begin
	   state <= `NRV_IS_IO_ADDR(addr_reg) ? WAIT_ALU_OR_MEM : FETCH_INSTR;
           addr_reg <= PC;	   
	end
	
        // *********************************************************************
        // Used by LOAD,STORE and by multi-cycle ALU instr (shifts and RV32M ops), 
	// writeback from ALU or memory, also waits from data from IO 
	// (listens to mem_rbusy and mem_wbusy)

        state[WAIT_ALU_OR_MEM_bit]: begin
           if(!aluBusy & !mem_rbusy & !mem_wbusy) begin
              addr_reg <= PC;
	      state <= FETCH_INSTR;
           end
        end

        // *********************************************************************
        // All the remaining transitions. See note [3] at the end of this file.

        default: begin
          state <= {
	      state[FETCH_REGS_bit],  // FETCH_REGS      -> ADDR_AND_ALU 
	      1'b0,                   // *no transition* -> STORE (already done from EXECUTE)
	      state[LOAD_bit],        // LOAD,STORE      -> WAIT_ALU_OR_MEM
	      1'b0,                   // *no transition* -> LOAD (already done from EXECUTE)
	      state[ADDR_AND_ALU_bit],// ADDR_AND_ALU    -> EXECUTE
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
   
`ifdef NRV_COUNTER_WIDTH	       
   always @(posedge clk) cycles <= cycles + 1;
`endif
   
endmodule

`define NRV_FEMTORV32_DEFINED // Used by femtosoc.v (we have a processor).
`define NRV_FEMTORV32_QUARK   // Used by femtosoc.v (we use the "Quark").

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
//
// [3] In addition, using 1-hot encoding, it is possible to express a set of 
// transitions in a single statement, by setting each bit of state according 
// to the previous value of other bits of state (and optionally other conditions).
