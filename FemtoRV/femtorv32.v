// Bruno Levy, May 2020, learning Verilog,
//
// Trying to fit a minimalistic RV32I core on an IceStick,
// and trying to organize the source in such a way I can understand
// what I have written a while after...

`ifdef VERBOSE
  `define verbose(command) command
`else
  `define verbose(command)
`endif

`ifdef BENCH
 `ifdef QUIET
  `define bench(command) 
 `else
  `define bench(command) command
 `endif
`else
  `define bench(command)
`endif

/***************************** REGISTER FILE *****************************/

module NrvRegisterFile(
  input 	    clk, 
  input [31:0] 	    in,        // Data for write back register
  input [4:0] 	    inRegId,   // Register to write back to
  input 	    inEn,      // Enable register write back
  input [4:0] 	    outRegId1, // Register number for out1
  input [4:0] 	    outRegId2, // Register number for out2
  output reg [31:0] out1, // Data out 1, available one clock after outRegId1 is set
  output reg [31:0] out2  // Data out 2, available one clock after outRegId2 is set
);
   // Register file is duplicated so that we can read rs1 and rs2 simultaneously
   // It is a bit stupid, it wastes four (inferred) SB_RAM40_4K BRAMs, where a single
   // one would suffice, but it makes things simpler (and the CPU faster).
   
   reg [31:0]  bank1 [30:0];
   reg [31:0]  bank2 [30:0];

   always @(posedge clk) begin
      if (inEn) begin
	 // This test seems to be needed ! (else J followed by LI results in wrong result)
	 if(inRegId != 0) begin 
	    bank1[~inRegId] <= in;
	    bank2[~inRegId] <= in;
	 end	  
      end 

      // Test bench does not seem to understand that
      // oob access in reg array is supposed to return 0.
      // TODO: test whether it is also required by the
      // IceStick version (does not seem to be the case).
`ifdef BENCH	 
      out1 <= (outRegId1 == 0) ? 0 : bank1[~outRegId1];
      out2 <= (outRegId2 == 0) ? 0 : bank2[~outRegId2];
`else
      out1 <= bank1[~outRegId1];
      out2 <= bank2[~outRegId2];
`endif

   end
endmodule


/********************************* ALU **********************************/

module NrvALU(
  input 	    clk, 
  input [31:0] 	    in1,
  input [31:0] 	    in2,
  input [2:0] 	    op,     // Operation
  input 	    opqual, // Operation qualification (+/-, Logical/Arithmetic)
  output reg [31:0] out,    // ALU result. Latched if operation is a shift.
  output 	    busy,   // 1 if ALU is currently computing (that is, shift ops)
  input 	    wr      // Raise to compute and store ALU result
);

   reg [4:0] shamt = 0; // current shift amount
   
   // ALU is busy if shift amount is non-zero, or if, at execute
   // state, operation is a shift (wr active)
   assign busy = (shamt != 0);
   
   reg [31:0] shifter;
   
   always @(*) begin
      (* parallel_case, full_case *)
      case(op)
        3'b000: out = opqual ? in1 - in2 : in1 + in2;                 // ADD/SUB
        3'b010: out = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0 ; // SLT
        3'b011: out = (in1 < in2) ? 32'b1 : 32'b0;                    // SLTU
        3'b100: out = in1 ^ in2;                                      // XOR
        3'b110: out = in1 | in2;                                      // OR
        3'b111: out = in1 & in2;                                      // AND
        3'b001: out = shifter;                                        // SLL	   
        3'b101: out = shifter;                                        // SRL/SRA
      endcase 
   end

   always @(posedge clk) begin
      
      /* verilator lint_off WIDTH */
      /* verilator lint_off CASEINCOMPLETE */
      
      if(wr) begin
	 case(op)
           3'b001: begin shifter <= in1; shamt <= in2[4:0]; end // SLL	   
           3'b101: begin shifter <= in1; shamt <= in2[4:0]; end // SRL/SRA
	 endcase 
      end else begin

`ifdef NRV_TWOSTAGE_SHIFTER
	 if (shamt > 4) begin
	    shamt <= shamt - 4;
	    case(op)
              3'b001: shifter <= shifter << 4;                                // SLL
	      3'b101: shifter <= opqual ? {{4{shifter[31]}}, shifter[31:4]} : // SRL/SRA 
                                          { 4'b0000,         shifter[31:4]} ; 
	    endcase 
	 end else  
`endif

	 if (shamt != 0) begin
	    shamt <= shamt - 1;
	    case(op)
              3'b001: shifter <= shifter << 1;                           // SLL
	      3'b101: shifter <= opqual ? {shifter[31], shifter[31:1]} : // SRL/SRA 
                                          {1'b0,        shifter[31:1]} ; 
	    endcase 
	 end

	 /* verilator lint_on WIDTH */
	 /* verilator lint_on CASEINCOMPLETE */
      end 
   end
   
endmodule

/********************* Branch predicates *******************************/

module NrvPredicate(
   input [31:0] in1,
   input [31:0] in2,
   input [2:0]  op, // Operation
   output reg   out
);
   always @(*) begin
      (* parallel_case, full_case *)	 
      case(op)
        3'b000: out = (in1 == in2);                   // BEQ
        3'b001: out = (in1 != in2);                   // BNE
        3'b100: out = ($signed(in1) < $signed(in2));  // BLT
        3'b101: out = ($signed(in1) >= $signed(in2)); // BGE
        3'b110: out = (in1 < in2);                    // BLTU
	3'b111: out = (in1 >= in2);                   // BGEU
	default: out = 1'bx; // don't care...
      endcase
   end
endmodule

/********************* Instruction decoder *******************************/

module NrvDecoder(
    input wire [31:0] instr,
    output wire [4:0] writeBackRegId,
    output reg 	      writeBackEn,
    output reg [1:0]  writeBackSel, // 00: ALU, 01: PC+4, 10: RAM
    output wire [4:0] inRegId1,
    output wire [4:0] inRegId2,
    output reg 	      aluSel, // 0: force aluOp,aluQual to zero (ADD)  1: use aluOp,aluQual from instr field
    output reg 	      aluInSel1, // 0: reg  1: pc
    output reg 	      aluInSel2, // 0: reg  1: imm
    output [2:0]      aluOp,
    output reg 	      aluQual,
    output reg 	      isLoad,
    output reg 	      isStore,
    output reg        needWaitAlu,
    output reg [1:0]  nextPCSel, // 00: PC+4  01: ALU  10: (predicate ? ALU : PC+4)
    output reg [31:0] imm,
    output reg 	      error
);

   reg inRegId1Sel; // 0: force inRegId1 to zero 1: use inRegId1 instr field

   // Reference:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf
   // See the table page 104


   // The beauty of RiscV: the instruction decoder is reasonably simple, because
   // - register ids and alu operation are always encoded in the same bits
   // - sign expansion for immediates is always done from bit 31, and minimum
   //   shuffling (nice compromise with register IDs and aluOp that are always
   //   the same bits). 

   // The control signals directly deduced from (fixed pos) fields
   
   assign writeBackRegId = instr[11:7];
   assign inRegId1       = instr[19:15] & {5{inRegId1Sel}}; // Internal sig InRegId1Sel used to force zero in reg1
   assign inRegId2       = instr[24:20];              // (because I'm maing maximum reuse of the adder of the ALU)
   assign aluOp          = instr[14:12];  

   // The five immediate formats, see the RiscV reference, Fig. 2.4 p. 12
   // Note: they all do sign expansion (sign bit is instr[31]), except the U format

   
   wire [20:0] immB1 = {21{instr[31]}}; // Do sign expansion only once
   
   wire [5:0]  immB2 = instr[30:25];    //  \
   wire [3:0]  immB3 = instr[24:21];    //  - These three blocks are reused
   wire [7:0]  immB4 = instr[19:12];    //  /   by several formats.

   wire [31:0] Iimm = {immB1,       immB2, immB3, instr[20]};
   wire [31:0] Simm = {immB1,       immB2, instr[11:8], instr[7]};
   wire [31:0] Bimm = {immB1[19:0], instr[7], immB2, instr[11:8], 1'b0};
   wire [31:0] Jimm = {immB1[11:0], immB4, instr[20], immB2, immB3, 1'b0};   
   wire [31:0] Uimm = {instr[31],   instr[30:20], immB4, {12{1'b0}}};


/*   
   // The previous version it is equivalent to this simpler version, but the
   // previous version sometimes (but not always) saves some LUTs and gains 
   // some nano-s.
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   
   wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
*/

   // The rest of instruction decoding, for the following signals:
   // writeBackEn
   // writeBackSel   00: ALU  01: PC+4 10: RAM
   // inRegId1Sel    0: zero   1: regId
   // aluInSel1      0: reg    1: PC 
   // aluInSel2      0: reg    1: imm
   // aluQual        +/- SRLI/SRAI
   // aluSel         0: force aluOp,aluQual=00  1: use aluOp/aluQual
   // nextPCSel      00: PC+4  01: ALU   10: (pred ? ALU : PC+4)
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
   //  - For ALU ops with immediates, aluQual is 0, except
   //    for shifts (then it is instr[30]).
   wire aluOpIsShift = (aluOp == 3'b001) || (aluOp == 3'b101);
   
   always @(*) begin

       error = 1'b0;
       nextPCSel = 2'b00;  // default: PC <- PC+4
       inRegId1Sel = 1'b1; // reg 1 Id from instr
       isLoad = 1'b0;
       isStore = 1'b0;
       aluQual = 1'b0;
       needWaitAlu = 1'b0;
      
       (* parallel_case, full_case *)
       case(instr[6:0])
	   7'b0110111: begin // LUI
	      writeBackEn  = 1'b1;   // enable write back
	      writeBackSel = 2'b00;  // write back source = ALU
	      inRegId1Sel = 1'b0;    // reg 1 Id = 0
	      aluInSel1 = 1'b0;      // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;      // ALU source 2 = imm
	      aluSel = 1'b0;         // ALU op = ADD
	      imm = Uimm;            // imm format = U
	   end
	 
	   7'b0010111: begin // AUIPC
	      writeBackEn  = 1'b1;   // enable write back
	      writeBackSel = 2'b00;  // write back source = ALU
	      inRegId1Sel = 1'bx;    // reg 1 Id : don't care (we use PC)	      
	      aluInSel1 = 1'b1;      // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;      // ALU source 2 = imm
	      aluSel = 1'b0;         // ALU op = ADD
	      imm = Uimm;            // imm format = U
	   end
	 
	   7'b1101111: begin // JAL
	      writeBackEn  = 1'b1;   // enable write back
	      writeBackSel = 2'b01;  // write back source = PC+4
	      inRegId1Sel = 1'bx;    // reg 1 Id : don't care (we use PC)	      	      
	      aluInSel1 = 1'b1;      // ALU source 1 = PC	      
	      aluInSel2 = 1'b1;      // ALU source 2 = imm
	      aluSel = 1'b0;         // ALU op = ADD
	      nextPCSel = 2'b01;     // PC <- ALU	      
	      imm = Jimm;            // imm format = J
	   end
	 
	   7'b1100111: begin // JALR
	      writeBackEn  = 1'b1;   // enable write back
	      writeBackSel = 2'b01;  // write back source = PC+4
	      aluInSel1 = 1'b0;      // ALU source 1 = reg	      
	      aluInSel2 = 1'b1;      // ALU source 2 = imm
	      aluSel = 1'b0;         // ALU op = ADD
	      nextPCSel = 2'b01;     // PC <- ALU	      
	      imm = Iimm;            // imm format = I
	   end
	 
	   7'b1100011: begin // Branch
	      writeBackEn = 1'b0;    // disable write back
	      writeBackSel = 2'bxx;  // write back source = don't care
	      aluInSel1 = 1'b1;      // ALU source 1 : PC
	      aluInSel2 = 1'b1;      // ALU source 2 : imm
	      aluSel = 1'b0;         // ALU op = ADD
	      nextPCSel = 2'b10;     // PC <- pred ? ALU : PC+4	       
	      imm = Bimm;            // imm format = B
	   end
	   
	   7'b0010011: begin // ALU operation: Register,Immediate
	      writeBackEn = 1'b1;    // enable write back
	      writeBackSel = 2'b00;  // write back source = ALU
	      aluInSel1 = 1'b0;      // ALU source 1 : reg
	      aluInSel2  = 1'b1;     // ALU source 2 : imm
	                             // Qualifier for ALU op: SRLI/SRAI
	      aluQual = aluOpIsShift ? instr[30] : 1'b0;
	      needWaitAlu = aluOpIsShift;
	      aluSel = 1'b1;         // ALU op : from instr
	      imm = Iimm;            // imm format = I
	   end
	   
	   7'b0110011: begin // ALU operation: Register,Register
	      writeBackEn = 1'b1;    // enable write back
	      writeBackSel = 2'b00;  // write back source = ALU
	      aluInSel1 = 1'b0;      // ALU source 1 : reg
	      aluInSel2 = 1'b0;      // ALU source 2 : reg
	      aluQual = instr[30];   // Qualifier for ALU op: +/- SRL/SRA
	      aluSel = 1'b1;         // ALU op : from instr
	      needWaitAlu = aluOpIsShift;	      
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx; // don't care
	   end
	   
           7'b0000011: begin // Load
	      writeBackEn = 1'b1;   // enable write back
	      writeBackSel = 2'b10; // write back source = RAM
	      aluInSel1 = 1'b0;     // ALU source 1 = reg
	      aluInSel2 = 1'b1;     // ALU source 2 = imm
	      aluSel = 1'b0;        // ALU op = ADD
	      imm = Iimm;           // imm format = I
	      isLoad = 1'b1;
	   end
	 
           7'b0100011: begin // Store
	      writeBackEn = 1'b0;   // disable write back
	      writeBackSel = 2'bxx; // write back sel = don't care
	      aluInSel1 = 1'b0;     // ALU source 1 = reg
	      aluInSel2 = 1'b1;     // ALU source 2 = imm
	      aluSel = 1'b0;        // ALU op = ADD
	      imm = Simm;           // imm format = S
	      isStore = 1'b1;
	   end
	    
	   /* 
	   7'b0001111: begin // Fence
	   end
	   7'b1110011: begin // System
	   end
	   */
	 
           default: begin
	      writeBackEn = 1'b0;
	      error = 1'b1;
	      writeBackSel = 2'bxx;   
	      inRegId1Sel = 1'bx; 
	      aluInSel1 = 1'bx;      
	      aluInSel2 = 1'bx;      
	      aluSel = 1'bx;      
	      nextPCSel = 2'bxx;  
	      imm = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	   end
       endcase
   end

endmodule

/********************* Nrv processor *******************************/

module FemtoRV32(
   input 	     clk,
   output [31:0]     address,        // address bus, only ADDR_WIDTH bits are used
   output reg	     dataRd,         // active when reading data (but not when reading instr)
   input [31:0]      dataIn,         // input lines for both data and instr
   output reg [3:0]  dataWrByteMask, // write mask for individual bytes (1 means write byte)
   output reg [31:0] dataOut,        // data to be written
   input wire 	     reset,          // set to 0 to reset the processor
   output wire 	     error           // 1 if current instruction could not be decoded
);


   localparam INITIAL            = 9'b000000000;   
   localparam WAIT_INSTR         = 9'b000000001;
   localparam FETCH              = 9'b000000010;
   localparam USE_PREFETCHED     = 9'b000000100;
   localparam DECODE             = 9'b000001000;
   localparam EXECUTE            = 9'b000010000;
   localparam WAIT_ALU_OR_DATA   = 9'b000100000;
   localparam LOAD               = 9'b001000000;
   localparam STORE              = 9'b010000000;   
   localparam ERROR              = 9'b100000000;
   reg [8:0] state;

   
   reg [`ADDR_WIDTH-1:0] addressReg;
   reg [`ADDR_WIDTH-3:0] PC;

   assign address = addressReg;

   reg [31:0] instr;     // Latched instruction. 
   reg [31:0] nextInstr; // Prefetched instruction.

   initial begin
      dataRd = 1'b0;
      dataWrByteMask = 4'b0000;
      state = INITIAL;
      addressReg = 0;
      PC = 0;
   end
 
   // Next program counter in normal operation: advance one word
   // I do not use the ALU, I create an additional adder for that.
   wire [`ADDR_WIDTH-3:0] PCplus4 = PC + 1;

   // Internal signals, all generated by the decoder from the current instruction.
   wire [4:0] 	 writeBackRegId; // The register to be written back
   wire 	 writeBackEn;    // Needs to be asserted for writing back
   wire [1:0]	 writeBackSel;   // 00: ALU  01: PC+4  10: RAM
   wire [4:0] 	 regId1;         // Register output 1
   wire [4:0] 	 regId2;         // Register output 2
   wire 	 aluInSel1;      // 0: register  1: pc
   wire 	 aluInSel2;      // 0: register  1: imm
   wire 	 aluSel;         // 0: force aluOp,aluQual to zero (ADD)  1: use aluOp,aluQual from instr field
   wire [2:0] 	 aluOp;          // one of the 8 operations done by the ALU
   wire 	 aluQual;        // 'qualifier' used by some operations (+/-, logical/arith shifts)
   wire [1:0] 	 nextPCSel;      // 00: PC+4  01: ALU  10: (predicate ? ALU : PC+4)
   wire [31:0] 	 imm;            // immediate value decoded from the instruction
   wire          needWaitAlu;    // true if we need to wait for the ALU (if instr is a shift)
   wire 	 isLoad;         // guess what, true if instr is a load
   wire 	 isStore;        // guess what, true if instr is a store
   wire          decoderError;   // true if instr does not correspond to any known instr

   // The instruction decoder, that reads the current instruction 
   // and generates all the signals from it. It is in fact just a
   // big combinatorial function.
   
   NrvDecoder decoder(
     .instr(instr),		     
     .writeBackRegId(writeBackRegId),
     .writeBackEn(writeBackEn),
     .writeBackSel(writeBackSel),
     .inRegId1(regId1),
     .inRegId2(regId2),
     .aluInSel1(aluInSel1), 
     .aluInSel2(aluInSel2),
     .aluSel(aluSel),		     
     .aluOp(aluOp),
     .aluQual(aluQual),
     .needWaitAlu(needWaitAlu),		      
     .isLoad(isLoad),
     .isStore(isStore),
     .nextPCSel(nextPCSel),
     .imm(imm),
     .error(decoderError)     		     
   );

   // Maybe not necessary, but I'd rather latch this one,
   // if this one glitches, then it will break everything...
   reg error_latched;
   assign error = error_latched;
   
   wire [31:0] aluOut;
   wire        aluBusy;

   // The register file. At each cycle, it can read two
   // registers (available at next cycle) and write one.
   reg  [31:0] writeBackData;
   wire [31:0] regOut1;
   wire [31:0] regOut2;   
   NrvRegisterFile regs(
    .clk(clk),
    .in(writeBackData),
    .inEn(
	  writeBackEn && 	
	  (state == EXECUTE || state == WAIT_ALU_OR_DATA) && !aluBusy
	  // Do not write back when state == WAIT_INSTR, because
	  //   - in that case, was already written back during EXECUTE
	  //   - at that time, PCplus4 is already incremented (and JAL needs
	  //     the current one to be written back)
    ),
    .inRegId(writeBackRegId),		       
    .outRegId1(regId1),
    .outRegId2(regId2),
    .out1(regOut1),
    .out2(regOut2) 
   );

   // The ALU, partly combinatorial, partly state (for shifts).
   wire [31:0] aluIn1 = aluInSel1 ? {PC, 2'b00} : regOut1;
   wire [31:0] aluIn2 = aluInSel2 ? imm : regOut2;
   
   NrvALU alu(
    .clk(clk),	      
    .in1(aluIn1),
    .in2(aluIn2),
    .op(aluOp & {3{aluSel}}),
    .opqual(aluQual & aluSel),
    .out(aluOut),
    .wr(state == EXECUTE), 
    .busy(aluBusy)	      
   );


   // LOAD: decode datain based on type and address
   
   reg [31:0] decodedDataIn;   
   reg [15:0]  dataIn_H;
   reg [7:0]   dataIn_B;

   always @(*) begin
      (* parallel_case, full_case *)            
      case(address[1])
	1'b0: dataIn_H = dataIn[15:0];
	1'b1: dataIn_H = dataIn[31:16];
      endcase 
      
      (* parallel_case, full_case *)            
      case(address[1:0])
	2'b00: dataIn_B = dataIn[7:0];
	2'b01: dataIn_B = dataIn[15:8];
	2'b10: dataIn_B = dataIn[23:16];
	2'b11: dataIn_B = dataIn[31:24];
      endcase 

      // aluop[1:0] contains data size (00: byte, 01: half word, 10: word)
      // aluop[2] sign expansion toggle (0 = sign expansion, 1 = no sign expansion)
      (* parallel_case, full_case *)      
      case(aluOp[1:0])
	2'b00: decodedDataIn = {{24{aluOp[2]?1'b0:dataIn_B[7]}},dataIn_B};
	2'b01: decodedDataIn = {{16{aluOp[2]?1'b0:dataIn_H[15]}},dataIn_H};
	default: decodedDataIn = dataIn;
      endcase
   end

   // The value written back to the register file.
   always @(*) begin
      (* parallel_case, full_case *)
      case(writeBackSel)
	2'b00: writeBackData = aluOut;	
	2'b01: writeBackData = {PCplus4, 2'b00};
	2'b10: writeBackData = decodedDataIn; 
	default: writeBackData = {32{1'bx}};
      endcase 
   end

   // The predicate for conditional branches. 
   wire predOut;
   NrvPredicate pred(
    .in1(regOut1),
    .in2(regOut2),
    .op(aluOp),
    .out(predOut)		    
   );

   always @(posedge clk) begin
      `verbose($display("state = %h",state));
      if(!reset) begin
	 state <= INITIAL;
      end else
      case(state)
	INITIAL: begin
	   `verbose($display("INITIAL"));
	   state <= WAIT_INSTR;
	   addressReg <= 0;
	   PC <= 0;
	end
	WAIT_INSTR: begin
	   // this state to give enough time to fetch the 
	   // instruction. Used for jumps and taken branches (and 
	   // when fetching the first instruction). 
	   `verbose($display("WAIT_INSTR"));
	   state <= FETCH;
	end
	FETCH: begin
	   `verbose($display("FETCH"));	   
	   instr <= dataIn;
	   // update instr address so that next instr is fetched during
	   // decode (and ready if there was no jump or branch)
	   addressReg <= {PCplus4, 2'b00}; 
	   state <= DECODE;
	end
	USE_PREFETCHED: begin
	   `verbose($display("USE_PREFETCHED"));	   
	   instr <= nextInstr;
	   // update instr address so that next instr is fetched during
	   // decode (and ready if there was no jump or branch)
	   addressReg <= {PCplus4, 2'b00}; 
	   state <= DECODE;
	   dataWrByteMask <= 4'b0000;
	end
	DECODE: begin
	   `verbose($display("DECODE"));
	   `verbose($display("   PC             = %h",{PC,2b00}));	   
	   `verbose($display("   instr          = %h",instr));
	   `verbose($display("   imm            = %h", $signed(imm)));
	   `verbose($display("   regId1         = %h", regId1));
	   `verbose($display("   regId2         = %h", regId2));
	   `verbose($display("   regIdWB        = %h", writeBackRegId));
	   `verbose($display("   writeBackEn    = %b", writeBackEn));
	   `verbose($display("   writeBackSel   = %b", writeBackSel));
	   `verbose($display("   aluSel         = %b", aluSel));
	   `verbose($display("   aluInSel1      = %b", aluInSel1));
	   `verbose($display("   aluInSel2      = %b", aluInSel2));
	   `verbose($display("   aluOp,aluQual  = %b,%b", aluOp,aluQual));
	   `verbose($display("   isLoad,isStore = %b,%b", isLoad, isStore));
	   `verbose($display("   nextPCSel      = %b", nextPCSel));
	   `verbose($display("   error          = %b", error));
	   `verbose($display("   needWaitAlu    = %b", needWaitAlu));	   	   	   	   
	   // instr was just updated -> input register ids also
	   // input registers available at next cycle 
	   state <= EXECUTE;
	   error_latched <= decoderError;
	end
	EXECUTE: begin
	   `verbose($display("EXECUTE"));
	   `verbose($display("   regOut1        = %h", regOut1));
	   `verbose($display("   regOut2        = %h", regOut2));
	   `verbose($display("   aluIn1         = %h", aluIn1));
	   `verbose($display("   aluIn2         = %h", aluIn2));
	   `verbose($display("   aluOp,aluQual  = %b,%b", aluOp,aluQual));	   
	   `verbose($display("   aluOut         = %h", aluOut));
	   `verbose($display("   aluBusy        = %b", aluBusy));
	   `verbose($display("   isLoad,isStore = %b,%b", isLoad, isStore));
	   `verbose($display("   error          = %b", error));
	   `verbose($display("   writeBackData  = %h", writeBackData));
	   `verbose($display("   needWaitAlu    = %b", needWaitAlu));	   	   	   
	   // input registers are read, aluOut is up to date

	   // Lookahead instr.
	   nextInstr <= dataIn;

	   if(error_latched) begin
	      state <= ERROR;
	   end else if(isLoad) begin
	      state <= LOAD;
	      PC <= PCplus4;
	      addressReg <= aluOut;
	      dataRd <= 1'b1;
	   end else if(isStore) begin
	      state <= STORE;
	      PC <= PCplus4;
	      addressReg <= aluOut;
	   end else begin
	      case(nextPCSel)
		2'b00: begin // normal operation
		   PC <= PCplus4;
		   state <= needWaitAlu ? WAIT_ALU_OR_DATA : USE_PREFETCHED;
		end		   
		2'b01: begin // unconditional jump (JAL, JALR)
		   PC <= aluOut[31:2];
		   addressReg <= aluOut;
		   state <= WAIT_INSTR;
		end
		2'b10: begin // branch
		   if(predOut) begin
		      PC <= aluOut[31:2];
		      addressReg <= aluOut;
		      state <= WAIT_INSTR;
		   end else begin
		      PC <= PCplus4;
		      state <= USE_PREFETCHED;
		   end
		end
	      endcase 
	   end 
	end
	LOAD: begin
	   `verbose($display("LOAD"));
	   // data address (aluOut) was just updated
	   // data ready at next cycle
	   // we go to WAIT_ALU_OR_DATA to write back read data
	   state <= WAIT_ALU_OR_DATA;
	   dataRd <= 1'b0;
	end
	STORE: begin
	   `verbose($display("STORE"));
	   // data address was just updated
	   // data ready to be written now
	   state <= USE_PREFETCHED;
	   case(aluOp[1:0])
	     2'b00: begin
		case(address[1:0])
		  2'b00: begin
		     dataWrByteMask   <= 4'b0001;
		     dataOut <= {24'bxxxxxxxxxxxxxxxxxxxxxxxx,regOut2[7:0]};
		  end
		  2'b01: begin
		     dataWrByteMask   <= 4'b0010;
		     dataOut <= {16'bxxxxxxxxxxxxxxxx,regOut2[7:0],8'bxxxxxxxx};
		  end
		  2'b10: begin
		     dataWrByteMask   <= 4'b0100;
		     dataOut <= {8'bxxxxxxxx,regOut2[7:0],16'bxxxxxxxxxxxxxxxx};
		  end
		  2'b11: begin
		     dataWrByteMask   <= 4'b1000;
		     dataOut <= {regOut2[7:0],24'bxxxxxxxxxxxxxxxxxxxxxxxx};
		  end
		endcase
	     end
	     2'b01: begin
		case(address[1])
		  1'b0: begin
		     dataWrByteMask   <= 4'b0011;
		     dataOut <= {16'bxxxxxxxxxxxxxxxx,regOut2[15:0]};
		  end
		  1'b1: begin
		     dataWrByteMask   <= 4'b1100;
		     dataOut <= {regOut2[15:0],16'bxxxxxxxxxxxxxxxx};
		  end
		endcase
	     end
	     2'b10: begin
		dataWrByteMask <= 4'b1111;
		dataOut <= regOut2;
	     end
	     default: begin
		dataWrByteMask   <= 4'bxxxx;
		dataOut <= 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	     end
	   endcase 
	end
	WAIT_ALU_OR_DATA: begin
	   `verbose($display("WAIT_INSTR_AND_ALU"));	   
	   // - If ALU is still busy, continue to wait.
	   // - register writeback is active
	   state <= aluBusy ? WAIT_ALU_OR_DATA : USE_PREFETCHED;
	   //if(isLoad) begin
	   //   `bench($display("   address=%h",addressReg));	      
	   //   `bench($display("   datain=%h",dataIn));
	   //end
	end
	ERROR: begin
	   `bench($display("ERROR"));
           state <= ERROR;
	end
	default: begin
	   `bench($display("UNKNOWN STATE"));	   	   	   
	   state <= ERROR;
	end
      endcase
  end   
   
endmodule

