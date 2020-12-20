/********************* Instruction decoder *******************************/

module NrvDecoder(
    input wire [31:0] instr,          // The instruction to be decoded
    output wire [4:0] writeBackRegId, // The register to be written back
    output reg 	      writeBackEn,    // Asserted when writing to a reg.
		  
    output reg 	      writeBackALU,    // \
    output reg 	      writeBackPCplus4,// | Data source for register
    output reg 	      writeBackAplusB, // | write-back (if enabled)
    output reg 	      writeBackCSR,    // /
		  
    output wire [4:0] inRegId1, // Register output 1
    output wire [4:0] inRegId2, // Register output 2

    output reg 	      aluInSel1, // ALU source selection 0: register  1: pc
    output reg 	      aluInSel2, //                      0: register  1: imm
    output [2:0]      func,      // operation done by the ALU, tests, load/store mode
    output reg 	      funcQual,  // 'qualifier' used by some operations (+/-, logic/arith shifts)
    output reg 	      funcM,     // asserted if instr is RV32M.

    output reg 	      isALU,     // \
    output reg 	      isLoad,    // |
    output reg 	      isStore,   // ) Guess what !
    output reg 	      isBranch,  // |
    output reg 	      isJump,    // /
		  
    output reg 	      needWaitALU, // asserted if instruction uses at least 1  cycle in ALU
		  
    output reg [31:0] imm,   // immediate value decoded from the instruction
		  
    output reg 	      error  // true if instr has invalid opcode
);

   reg inRegId1Sel; // 0: force inRegId1 to zero 1: use inRegId1 instr field

   // Reference:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf
   // See the table page 104

   // The beauty of RiscV: the instruction decoder is reasonably simple, because
   // - register ids and alu operation are always encoded in the same bits
   // - sign expansion for immediates is always done from bit 31, and minimum
   //   shuffling (nice compromise with register IDs and func that are always
   //   the same bits). 

   // The control signals directly deduced from (fixed pos) fields
   
   assign writeBackRegId = instr[11:7];
   assign inRegId1       = instr[19:15] & {5{inRegId1Sel}}; // Internal sig InRegId1Sel used to force zero in reg1
   assign inRegId2       = instr[24:20];             // (because I'm making maximum reuse of the adder of the ALU)
   assign func          = instr[14:12];  

   // The five immediate formats, see the RiscV reference, Fig. 2.4 p. 12
   // Note: they all do sign expansion (sign bit is instr[31]), except the U format
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   
   wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};

   // The rest of instruction decoding, for the following signals:
   // writeBackEn
   // writeBack source: one of writeBackALU, writeBackPCplus4, writeBackAplusB, writeBackCSR,
   // inRegId1Sel    0: zero   1: regId
   // aluInSel1      0: reg    1: PC 
   // aluInSel2      0: reg    1: imm
   // funcQual        +/- SRLI/SRAI
   // funcM           1 if instr is RV32M
   // imm (select one of Iimm,Simm,Bimm,Jimm,Uimm)

   // The beauty of RiscV (again !): in fact there are only 11 instructions !
   //
   // LUI, AUIPC, JAL, JALR
   // Branch variants
   // ALU register variants
   // ALU immediate variants
   // Load, Store 
   // Fence, System (not implemented)

   // We need to distingish shifts for two reasons:
   //  - We need to wait for ALU when it is a shift
   //  - For ALU ops with immediates, funcQual is 0, except
   //    for shifts (then it is instr[30]).
   wire funcIsShift = (func == 3'b001) || (func == 3'b101);
   
   always @(*) begin

       error = 1'b0;
       inRegId1Sel = 1'b1; // default: reg 1 Id from instr
       isALU = 1'b0;
       isLoad = 1'b0;
       isStore = 1'b0;
       isBranch = 1'b0;
       isJump = 1'b0;
       funcQual = 1'b0;
       needWaitALU = 1'b0;
       funcM = 1'b0;
       
       writeBackEn  = 1'b0;
       writeBackALU = 1'b0;
       writeBackPCplus4 = 1'b0;
       writeBackAplusB = 1'b0;
       writeBackCSR = 1'b0;
      
       (* parallel_case, full_case *)
       case(instr[6:0])
	   7'b0110111: begin // LUI
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackAplusB = 1'b1; // write back source = A+B
	      inRegId1Sel = 1'b0;     // reg 1 Id = 0
	      aluInSel1 = 1'b0;       // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Uimm;             // imm format = U
	   end
	 
	   7'b0010111: begin // AUIPC
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackAplusB = 1'b1;    // write back source = A+B
	      inRegId1Sel = 1'bx;     // reg 1 Id : don't care (we use PC)	      
	      aluInSel1 = 1'b1;       // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Uimm;             // imm format = U
	   end
	 
	   7'b1101111: begin // JAL
	      writeBackEn  = 1'b1;     // enable write back
	      writeBackPCplus4 = 1'b1; // write back source = PC+4
	      inRegId1Sel = 1'bx;      // reg 1 Id : don't care (we use PC)	      	      
	      aluInSel1 = 1'b1;        // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;        // ALU source 2 = imm
	      isJump = 1'b1;           // PC <- ALU
	      imm = Jimm;              // imm format = J
	   end
	 
	   7'b1100111: begin // JALR
	      writeBackEn  = 1'b1;     // enable write back
	      writeBackPCplus4 = 1'b1; // write back source = PC+4
	      aluInSel1 = 1'b0;        // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;        // ALU source 2 = imm
	      isJump = 1'b1;           // PC <- ALU	      
	      imm = Iimm;              // imm format = I
	   end
	 
	   7'b1100011: begin // Branch
	      aluInSel1 = 1'b1;       // ALU source 1 : PC
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	      isBranch = 1'b1;        // PC <- pred ? ALU : PC+4	       
	      imm = Bimm;             // imm format = B
	   end
	   
	   7'b0010011: begin // ALU operation: Register,Immediate
	      writeBackEn = 1'b1;     // enable write back
	      writeBackALU = 1'b1;    // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	                              // Qualifier for ALU op: SRLI/SRAI
	      funcQual = funcIsShift ? instr[30] : 1'b0;
`ifdef NRV_LATCH_ALU
	      needWaitALU = 1'b1;	      
`else
	      needWaitALU = funcIsShift;
`endif	      
	      isALU = 1'b1;           // ALU op : from instr
	      imm = Iimm;             // imm format = I
	   end
	   
	   7'b0110011: begin // ALU operation: Register,Register
	      writeBackEn = 1'b1;     // enable write back
	      writeBackALU = 1'b1;    // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b0;       // ALU source 2 : reg
	      funcQual = instr[30];   // Qualifier for ALU op: +/- SRL/SRA
	      isALU = 1'b1;           // ALU op : from instr
`ifdef NRV_RV32M
 `ifdef NRV_LATCH_ALU
	      needWaitALU = 1'b1;
 `else
	      needWaitALU = funcIsShift || instr[25];
 `endif
              funcM = instr[25];
`else
 `ifdef NRV_LATCH_ALU
	      needWaitALU = 1'b1;	      
 `else
	      needWaitALU = funcIsShift;
 `endif	      
	      error = instr[25];
`endif	      
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; // don't care
	   end
	   
           7'b0000011: begin // Load
	      writeBackEn = 1'b1;     // enable write back
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Iimm;             // imm format = I
	      isLoad = 1'b1;
	   end
	 
           7'b0100011: begin // Store
	      writeBackEn = 1'b0;     // disable write back
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Simm;             // imm format = S
	      isStore = 1'b1;
	   end
	    
`ifdef NRV_COUNTERS
           // System RDCYCLE[H], RDTIME[H] and RDINSTRET[H]
	   // TODO: other system instr
	   7'b1110011: begin 
	      writeBackEn = 1'b1;
	      writeBackCSR = 1'b1; // write back sel = counter
	      inRegId1Sel = 1'bx; 
	      aluInSel1 = 1'bx;      
	      aluInSel2 = 1'bx;      
	      isALU = 1'bx;      
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	   end
`endif	 
  
           // TODO: Fence (can we map it to NOP ?)
	   // 7'b0001111: begin 
	   // end

           default: begin
	      writeBackEn = 1'b0;
	      error = 1'b1;
	      aluInSel1 = 1'bx;      
	      aluInSel2 = 1'bx;      
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	   end
       endcase
   end

endmodule
