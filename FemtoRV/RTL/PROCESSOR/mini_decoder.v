/********************* Instruction decoder *******************************/

// Minimalistic version of the instruction decoder, 
// this version does not check for errors.
// There is probably room for improvement in the big case()
// statement on 7 bits instruction codes (the last two bits 
// are always ones). Tried on 5 bits -> more LUTs. Tried also
// with casez -> more LUTs. 

module NrvDecoder(
    input wire [31:0] instr,          // The instruction to be decoded
    output wire [4:0] writeBackRegId, // The register to be written back
    output reg 	      writeBackEn,    // Asserted when writing to a reg.
		  
    output reg 	      writeBackALU,    // \
    output reg 	      writeBackPCplus4,// | Data source for register
    output reg 	      writeBackAplusB, // / write-back (if enabled)
		  
    output wire [4:0] inRegId1, // Register output 1
    output wire [4:0] inRegId2, // Register output 2

    output reg 	      aluInSel1, // ALU source selection 0: register  1: pc
    output reg 	      aluInSel2, //                      0: register  1: imm
    output [2:0]      func,      // operation done by the ALU, tests, load/store mode
    output reg 	      funcQual,  // 'qualifier' used by some operations (+/-, logic/arith shifts)

    output reg 	      isALU,     // \
    output reg 	      isLoad,    // |
    output reg 	      isStore,   // ) Guess what !
    output reg 	      isBranch,  // |
    output reg 	      isJump,    // /
		  
    output reg [31:0] imm,   // immediate value decoded from the instruction
		  
    output wire       error  // always 0 in this version that does not detect errors
);
   assign error = 1'b0;
   
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
   // writeBack source: one of writeBackALU, writeBackPCplus4, writeBackAplusB,
   // inRegId1Sel    0: zero   1: regId
   // aluInSel1      0: reg    1: PC 
   // aluInSel2      0: reg    1: imm
   // funcQual        +/- SRLI/SRAI
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

       inRegId1Sel = 1'b1; // default: reg 1 Id from instr
       isALU = 1'b0;
       isLoad = 1'b0;
       isStore = 1'b0;
       isBranch = 1'b0;
       isJump = 1'b0;
       funcQual = 1'b0;

       aluInSel1 = 1'bx;      
       aluInSel2 = 1'bx;      
       
       writeBackEn  = 1'bx;
       writeBackALU = 1'b0;
       writeBackPCplus4 = 1'b0;
       writeBackAplusB = 1'b0;

       imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;

       // The two LSBs are always 11 in the base RV32I instruction
       // set. In the mini decoder, we do not check for errors, so
       // we only use instr[6:2] (5 bits) to determine the instruction.
       
       (* parallel_case, full_case *)
       case(instr[6:2])
	   5'b01101: begin // LUI
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackAplusB = 1'b1; // write back source = A+B
	      inRegId1Sel = 1'b0;     // reg 1 Id = 0
	      aluInSel1 = 1'b0;       // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Uimm;             // imm format = U
	   end
	 
	   5'b00101: begin // AUIPC
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackAplusB = 1'b1; // write back source = A+B
	      inRegId1Sel = 1'bx;     // reg 1 Id : don't care (we use PC)	      
	      aluInSel1 = 1'b1;       // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Uimm;             // imm format = U
	   end
	 
	   5'b11011: begin // JAL
	      writeBackEn  = 1'b1;     // enable write back
	      writeBackPCplus4 = 1'b1; // write back source = PC+4
	      inRegId1Sel = 1'bx;      // reg 1 Id : don't care (we use PC)	      	      
	      aluInSel1 = 1'b1;        // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;        // ALU source 2 = imm
	      isJump = 1'b1;           // PC <- ALU
	      imm = Jimm;              // imm format = J
	   end
	 
	   5'b11001: begin // JALR
	      writeBackEn  = 1'b1;     // enable write back
	      writeBackPCplus4 = 1'b1; // write back source = PC+4
	      aluInSel1 = 1'b0;        // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;        // ALU source 2 = imm
	      isJump = 1'b1;           // PC <- ALU	      
	      imm = Iimm;              // imm format = I
	   end
	 
	   5'b11000: begin // Branch
	      writeBackEn  = 1'b0;    // disable write back
	      aluInSel1 = 1'b1;       // ALU source 1 : PC
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	      isBranch = 1'b1;        // PC <- pred ? ALU : PC+4	       
	      imm = Bimm;             // imm format = B
	   end
	   
	   5'b00100: begin // ALU operation: Register,Immediate
	      writeBackEn = 1'b1;     // enable write back
	      writeBackALU = 1'b1;    // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	                              // Qualifier for ALU op: SRLI/SRAI
	      funcQual = funcIsShift ? instr[30] : 1'b0;
	      isALU = 1'b1;           // ALU op : from instr
	      imm = Iimm;             // imm format = I
	   end
	   
	   5'b01100: begin // ALU operation: Register,Register
	      writeBackEn = 1'b1;     // enable write back
	      writeBackALU = 1'b1;    // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b0;       // ALU source 2 : reg
	      funcQual = instr[30];   // Qualifier for ALU op: +/- SRL/SRA
	      isALU = 1'b1;           // ALU op : from instr
	   end
	   
           5'b00000: begin // Load
	      writeBackEn = 1'b1;     // enable write back
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Iimm;             // imm format = I
	      isLoad = 1'b1;
	   end
	 
           5'b01000: begin // Store
	      writeBackEn  = 1'b0;    // disable write back
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      imm = Simm;             // imm format = S
	      isStore = 1'b1;
	   end

           default: begin
	   end

       endcase
   end

endmodule
