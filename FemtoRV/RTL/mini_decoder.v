/********************* Instruction decoder *******************************/
/* A drop-in replacement of the instruction decoder, meant to further    */
/* reduce LUT count by not checking for errors (but no success for now)  */

module NrvDecoder(
    input wire [31:0] instr,
    output wire [4:0] writeBackRegId,
    output reg 	      writeBackEn,
    output reg [3:0]  writeBackSel, // 0001: ALU  0010: PC+4  0100: RAM 1000: counters
		                    // (could use 2 wires instead, but using 4 wires (1-hot encoding) 
		                    //  reduces both LUT count and critical path in the end !)
    output wire [4:0] inRegId1,
    output wire [4:0] inRegId2,
    output reg 	      aluSel, // 0: force aluOp,aluQual to zero (ADD)  1: use aluOp,aluQual from instr field
    output reg 	      aluInSel1, // 0: reg  1: pc
    output reg 	      aluInSel2, // 0: reg  1: imm
    output [2:0]      aluOp,
    output reg 	      aluQual,
    output wire	      aluM, // Asserted if operation is an RV32M operation
    output reg 	      isLoad,
    output reg 	      isStore,
    output reg 	      needWaitALU,
    output reg [2:0]  nextPCSel, // 001: PC+4  010: ALU  100: (predicate ? ALU : PC+4)
		                 // (same as writeBackSel, 1-hot encoding)
    output reg [31:0] imm,
    output wire	      error
);

   assign error = 1'b0; // We do not check for errors in the MiniDecoder.
   assign aluM  = 1'b0; // MiniDecoder only works for RV32I 
   
    
   reg inRegId1Sel; // 0: force inRegId1 to zero 1: use inRegId1 instr field
   
   assign writeBackRegId = instr[11:7];
   assign inRegId1       = instr[19:15] & {5{inRegId1Sel}}; // Internal sig InRegId1Sel used to force zero in reg1
   assign inRegId2       = instr[24:20];             // (because I'm making maximum reuse of the adder of the ALU)
   assign aluOp          = instr[14:12];  

   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   
   wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};

   // The rest of instruction decoding, for the following signals:
   // writeBackEn
   // writeBackSel   0001: ALU  0010: PC+4 0100: RAM 1000: counters
   // inRegId1Sel    0: zero   1: regId
   // aluInSel1      0: reg    1: PC 
   // aluInSel2      0: reg    1: imm
   // aluQual        +/- SRLI/SRAI
   // aluM           1 if instr is RV32M
   // aluSel         0: force aluOp,aluQual=00  1: use aluOp/aluQual
   // nextPCSel      001: PC+4  010: ALU   100: (pred ? ALU : PC+4)
   // imm (select one of Iimm,Simm,Bimm,Jimm,Uimm)

   // We need to distingish shifts for two reasons:
   //  - We need to wait for ALU when it is a shift
   //  - For ALU ops with immediates, aluQual is 0, except
   //    for shifts (then it is instr[30]).
   wire aluOpIsShift = (aluOp == 3'b001) || (aluOp == 3'b101);
   
   always @(*) begin

       nextPCSel = 3'b001; // default: PC <- PC+4
       inRegId1Sel = 1'b1; // reg 1 Id from instr
       isLoad = 1'b0;
       isStore = 1'b0;
       aluQual = 1'b0;
       needWaitALU = 1'b0;

       (* parallel_case, full_case *)
       case(instr[6:2])
	   5'b01101: begin // LUI
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackSel = 4'b0001; // write back source = ALU
	      inRegId1Sel = 1'b0;     // reg 1 Id = 0
	      aluInSel1 = 1'b0;       // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Uimm;             // imm format = U
	   end
	 
	   5'b00101: begin // AUIPC
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackSel = 4'b0001; // write back source = ALU
	      inRegId1Sel = 1'bx;     // reg 1 Id : don't care (we use PC)	      
	      aluInSel1 = 1'b1;       // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Uimm;             // imm format = U
	   end
	 
	   5'b11011: begin // JAL
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackSel = 4'b0010; // write back source = PC+4
	      inRegId1Sel = 1'bx;     // reg 1 Id : don't care (we use PC)	      	      
	      aluInSel1 = 1'b1;       // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      nextPCSel = 3'b010;     // PC <- ALU	      
	      imm = Jimm;             // imm format = J
	   end
	 
	   5'b11001: begin // JALR
	      writeBackEn  = 1'b1;    // enable write back
	      writeBackSel = 4'b0010; // write back source = PC+4
	      aluInSel1 = 1'b0;       // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      nextPCSel = 3'b010;     // PC <- ALU	      
	      imm = Iimm;             // imm format = I
	   end
	 
	   5'b11000: begin // Branch
	      writeBackEn = 1'b0;     // disable write back
	      writeBackSel = 4'bxxxx; // write back source = don't care
	      aluInSel1 = 1'b1;       // ALU source 1 : PC
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	      aluSel = 1'b0;          // ALU op = ADD
	      nextPCSel = 3'b100;     // PC <- pred ? ALU : PC+4	       
	      imm = Bimm;             // imm format = B
	   end
	   
	   5'b00100: begin // ALU operation: Register,Immediate
	      writeBackEn = 1'b1;     // enable write back
	      writeBackSel = 4'b0001; // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b1;       // ALU source 2 : imm
	                              // Qualifier for ALU op: SRLI/SRAI
	      aluQual = aluOpIsShift ? instr[30] : 1'b0;
	      needWaitALU = aluOpIsShift;
	      aluSel = 1'b1;         // ALU op : from instr
	      imm = Iimm;            // imm format = I
	   end
	   
	   5'b01100: begin // ALU operation: Register,Register
	      writeBackEn = 1'b1;     // enable write back
	      writeBackSel = 4'b0001; // write back source = ALU
	      aluInSel1 = 1'b0;       // ALU source 1 : reg
	      aluInSel2 = 1'b0;       // ALU source 2 : reg
	      aluQual = instr[30];    // Qualifier for ALU op: +/- SRL/SRA
	      aluSel = 1'b1;          // ALU op : from instr
	      needWaitALU = aluOpIsShift;
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; // don't care
	   end
	   
           5'b00000: begin // Load
	      writeBackEn = 1'b1;     // enable write back
	      writeBackSel = 4'b0100; // write back source = RAM
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Iimm;             // imm format = I
	      isLoad = 1'b1;
	   end
	 
           5'b01000: begin // Store
	      writeBackEn = 1'b0;     // disable write back
	      writeBackSel = 4'bxxxx; // write back sel = don't care
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Simm;             // imm format = S
	      isStore = 1'b1;
	   end
	    
           default: begin
	      writeBackEn = 1'b0;
	      writeBackSel = 4'bxxxx;   
	      inRegId1Sel = 1'bx; 
	      aluInSel1 = 1'bx;      
	      aluInSel2 = 1'bx;      
	      aluSel = 1'bx;      
	      nextPCSel = 3'bxxx;  
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	   end
       endcase
   end

endmodule
