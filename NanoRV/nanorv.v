// Bruno Levy, May 2020, learning Verilog,
//
// Trying to fit a minimalistic RV32I core on an IceStick,
// and trying to organize the source in such a way I can understand
// what I have written a while after...

/*
 * Bugs:      - There is still somethig wrong ! if I test error flag, or
 *              if I test whether instr is zero, it always says yes...
 *              (unless I lower frequency), there is probably something
 *              I do wrong... Plus sometimes it does not start and stays
 *              stuck in error mode (D5 lit).
 *
 * See also NOTES.txt
 */

// Comment-out if running out of LUTs (makes shifter faster, but uses 66 LUTs)
// (inspired by PICORV32)
//`define NRV_TWOSTAGE_SHIFTER

`define NRV_RESET        // Reset button

// Optional mapped IO devices
`define NRV_IO_LEDS      // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_IO_UART_RX   // Mapped IO, virtual UART receiver    (USB)
//`define NRV_IO_UART_TX   // Mapped IO, virtual UART transmetter (USB)
`define NRV_IO_SSD1351   // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX2719   // Mapped IO, 8x8 led matrix

`define ADDR_WIDTH 14 // Internal number of bits for PC and address register.
                      // 6kb needs 13 bits, + 1 page for IO -> 14 bits

/*************************************************************************************/
// Makes it easier to detect typos !
`default_nettype none

// Used by the UART, needs to match frequency defined in the PLL, 
// at the end of the file
`define CLKFREQ   60000000
`include "uart.v"


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
  
   // The control signals directly deduced from (fixed pos) fields
   assign writeBackRegId = instr[11:7];
   assign inRegId1       = instr[19:15] & {5{inRegId1Sel}};   
   assign inRegId2       = instr[24:20];
   assign aluOp          = instr[14:12];  

   // The five immediate formats, see the RiscV reference, Fig. 2.4 p. 12
   // Note: they all do sign expansion (sign bit is instr[31]), except the U format
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:25], instr[24:21], instr[20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:8], instr[7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0};   
   wire [31:0] Uimm = {instr[31], instr[30:20], instr[19:12], {12{1'b0}}};

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

   // The beauty of RiscV: in fact there are only 11 instructions !
   //
   // LUI, AUIPC, JAL, JALR
   // Branch variants
   // ALU register variants
   // ALU immediate variants
   // Load, Store 
   // Fence, System (not implemented)

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

module NrvProcessor(
   input 	     clk,
   output [31:0]     address,
   output reg	     dataRd,
   input [31:0]      dataIn,
   output reg [3:0]  dataWrByteMask, // write mask for individual bytes
   output reg [31:0] dataOut,
   input wire 	     reset,
   output wire 	     error
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
   reg [`ADDR_WIDTH-1:0] PC;

   assign address = addressReg;

   reg [31:0]  	         instr;     // Latched instruction. 
   reg [31:0]            nextInstr; // Preftched instruction.

   initial begin
      dataRd = 1'b0;
      dataWrByteMask = 4'b0000;
      state = INITIAL;
      addressReg = 0;
      PC = 0;
   end
 
   // Next program counter in normal operation: advance one word
   // I do not use the ALU, I create an additional adder for that.
   wire [`ADDR_WIDTH-1:0] PCplus4 = PC + 4;

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
   wire          needWaitAlu;
   wire 	 isLoad;
   wire 	 isStore;
   wire          decoderError;

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

   reg [1:0] writeBackSel_latched;
   reg       writeBackEn_latched;
   reg       error_latched;
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
	  // Do not write back when state == WAIT_INSTR, because
	  //   - in that case, was already written back during EXECUTE
	  //   - at that time, PCplus4 is already incremented (and JAL needs 
	  //     the current one)
	  (state == EXECUTE || state == WAIT_ALU_OR_DATA) && !aluBusy 
    ),
    .inRegId(writeBackRegId),		       
    .outRegId1(regId1),
    .outRegId2(regId2),
    .out1(regOut1),
    .out2(regOut2) 
   );

   // The ALU, partly combinatorial, partly state (for shifts).
   wire [31:0] aluIn1 = aluInSel1 ? PC  : regOut1;
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


   // LOAD: decode data in based on type and address
   
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
      // aluop[2] sign expansion toggle     
      (* parallel_case, full_case *)      
      case(aluOp_latched[1:0])
	2'b00: decodedDataIn = {{24{aluOp_latched[2]?dataIn_B[7]:1'b0}},dataIn_B};
	2'b01: decodedDataIn = {{16{aluOp_latched[2]?dataIn_H[15]:1'b0}},dataIn_H};
	default: decodedDataIn = dataIn;
      endcase
   end

   // The value written back to the register file.
   always @(*) begin
      (* parallel_case, full_case *)
      case(writeBackSel_latched)
	2'b00: writeBackData = aluOut;	
	2'b01: writeBackData = PCplus4;
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

   reg      waitAlu;
   reg      isLoad_latched;
   reg      isStore_latched;
   reg[1:0] nextPCSel_latched;
   reg [2:0] aluOp_latched;
   
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
	   // this state to give enough time to fetch the first
	   // instruction (else we are in the error state)
	   // (in fact does not work, seems that we start in the error state,
	   //  to be debugged, see comments in the DECODE state)
	   `verbose($display("WAIT_INSTR"));
	   state <= FETCH;
	end
	FETCH: begin
	   `verbose($display("FETCH"));	   
	   instr <= dataIn;
	   // update instr address so that next instr is fetched during
	   // decode (and ready if there was no jump or branch)
	   addressReg <= PCplus4; 
	   state <= DECODE;
	end
	USE_PREFETCHED: begin
	   `verbose($display("USE_PREFETCHED"));	   
	   instr <= nextInstr;
	   // update instr address so that next instr is fetched during
	   // decode (and ready if there was no jump or branch)
	   addressReg <= PCplus4; 
	   state <= DECODE;
	   dataWrByteMask <= 4'b0000;
	end
	DECODE: begin
	   // instr was just updated -> input register ids also
	   // input registers available at next cycle 
	   
	   state <= EXECUTE;  // Not okay, but okay after reset, why ?
	   // state <= EXECUTE; // So for now I do that ... (to be investigated)

	   `verbose($display("DECODE"));
	   `verbose($display("   PC             = %h",PC));	   
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
	   waitAlu <= needWaitAlu;
	   isLoad_latched <= isLoad;
	   isStore_latched <= isStore;
	   nextPCSel_latched <= nextPCSel;
	   aluOp_latched <= aluOp;
	   writeBackSel_latched <= writeBackSel;
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
	   // input registers are read, aluOut is up to date

	   // Lookahead instr.
	   nextInstr <= dataIn;

	   if(error_latched) begin
	      state <= ERROR;
	   end else if(isLoad_latched) begin
	      state <= LOAD;
	      PC <= PCplus4;
	      addressReg <= aluOut;
	      dataRd <= 1'b1;
	   end else if(isStore_latched) begin
	      state <= STORE;
	      PC <= PCplus4;
	      addressReg <= aluOut;
	   end else begin
	      case(nextPCSel_latched)
		2'b00: begin // normal operation
		   PC <= PCplus4;
		   state <= needWaitAlu ? WAIT_ALU_OR_DATA : USE_PREFETCHED;
		end		   
		2'b01: begin // unconditional jump (JAL, JALR)
		   PC <= aluOut;
		   addressReg <= aluOut;
		   state <= WAIT_INSTR;
		end
		2'b10: begin // branch
		   if(predOut) begin
		      PC <= aluOut;
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
	   case(aluOp_latched[1:0])
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
	   waitAlu <= 1'b0;
	   state <= aluBusy ? WAIT_ALU_OR_DATA : USE_PREFETCHED;
	   if(isLoad) begin
	      `bench($display("   address=%h",addressReg));	      
	      `bench($display("   datain=%h",dataIn));
	   end
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

/********************* Nrv RAM *******************************/

// Memory map: 4 pages of 256 32bit words + 1 virtual page for IO
// Memory address: page[2:0] offset[7:0] byte_offset[1:0]
//
// Access to memory is 'typed', using dataType, directly mapped to
// the corresponding field of the RISC-V LOAD and STORE operations.
//
// Page 3'b100 is used for memory-mapped IO's, that redirects the
// signals to IOaddress, IOwr, IOrd, IOin, IOout.

module NrvMemoryInterface(
  input 	    clk,
  input [13:0] 	    address, 
  input [3:0] 	    wrByteMask,
  input 	    rd,
  input [31:0] 	    in,
  output reg [31:0] out,

  output [7:0] 	    IOaddress, // = address[9:2]
  output 	    IOwr,
  output 	    IOrd,
  input [31:0] 	    IOin, 
  output [31:0]     IOout
);

   wire             isIO   = address[13];
   wire [2:0] 	    page   = address[12:10];
   wire [7:0] 	    offset = address[9:2];
   wire [10:0] 	    addr_internal = {3'b000,offset};

   wire 	    wr    = (wrByteMask != 0);
   wire             wrRAM = wr && !isIO;
   wire             rdRAM = 1'b1; // rd && !isIO; 
                                  // (but in fact if we always read, it does not harm..., 
                                  // and I'm missing read signal for instr)

   reg [31:0] RAM[1023:0]; // 4K
// reg [31:0] RAM[1279:0]; // 5K    
// reg [31:0] RAM[1535:0]; // 6K 
   reg [31:0] out_RAM;

   initial begin
      $readmemh("FIRMWARE/firmware.hex",RAM);
   end

   wire [10:0] word_addr = {page,offset};
   
   always @(posedge clk) begin
      if(wrRAM) begin
	 if(wrByteMask[0]) RAM[word_addr][ 7:0 ] <= in[ 7:0 ];
	 if(wrByteMask[1]) RAM[word_addr][15:8 ] <= in[15:8 ];
	 if(wrByteMask[2]) RAM[word_addr][23:16] <= in[23:16];
	 if(wrByteMask[3]) RAM[word_addr][31:24] <= in[31:24];	 
      end 
      if(rdRAM) begin
	 out_RAM <= RAM[word_addr];
      end
   end

   always @(*) begin
      out = isIO ? IOin : out_RAM;
   end   
   
   assign IOout     = in;
   assign IOwr      = (wr && isIO);
   assign IOrd      = (rd && isIO);
   assign IOaddress = offset;
   
endmodule

/********************* Nrv IO  *******************************/

module NrvIO(
    input 	      clk, 
    input [7:0]       address, 
    input 	      wr,
    output 	      rd,
    input [31:0]      in, 
    output reg [31:0] out,

    // LEDs D1-D4	     
    output reg [3:0]  LEDs,

    // Oled display
    output            SSD1351_DIN, 
    output            SSD1351_CLK, 
    output 	      SSD1351_CS, 
    output reg 	      SSD1351_DC, 
    output reg 	      SSD1351_RST,
    
    // Serial
    input  	      RXD,
    output            TXD,

    // Led matrix
    output            MAX2719_DIN, 
    output            MAX2719_CS, 
    output            MAX2719_CLK 
);

   /***** Memory-mapped ports, all 32 bits, address/4 *******/
   
   localparam LEDs_address         = 0; // (write) LEDs (4 LSBs)
   localparam SSD1351_CNTL_address = 1; // (read/write) Oled display control
   localparam SSD1351_CMD_address  = 2; // (write) Oled display commands (8 bits)
   localparam SSD1351_DAT_address  = 3; // (write) Oled display data (8 bits)
   localparam UART_RX_CNTL_address = 4; // (read) LSB: data ready
   localparam UART_RX_DAT_address  = 5; // (read) received data (8 bits)
   localparam UART_TX_CNTL_address = 6; // (read) LSB: busy
   localparam UART_TX_DAT_address  = 7; // (write) data to be sent (8 bits)
   localparam MAX2719_CNTL_address = 8; // (read) led matrix LSB: busy
   localparam MAX2719_DAT_address  = 9; // (write)led matrix data (16 bits)
    
   
   /********************** SSD1351 **************************/

`ifdef NRV_IO_SSD1351
   initial begin
      SSD1351_DC  = 1'b0;
      SSD1351_RST = 1'b0;
      LEDs        = 4'b0000;
   end
   
   // Currently sent bit, 1-based index
   // (0000 config. corresponds to idle)
   reg      SSD1351_slow_clk; // clk=60MHz, slow_clk=30MHz
   reg[3:0] SSD1351_bitcount = 4'b0000;
   reg[7:0] SSD1351_shifter = 0;
   wire     SSD1351_sending = (SSD1351_bitcount != 0);
   reg      SSD1351_special; // pseudo-instruction, direct control of RST and DC.

   assign SSD1351_DIN = SSD1351_shifter[7];
   assign SSD1351_CLK = SSD1351_sending && !SSD1351_slow_clk;
   assign SSD1351_CS  = SSD1351_special ? 1'b0 : !SSD1351_sending;

   always @(posedge clk) begin
      SSD1351_slow_clk <= ~SSD1351_slow_clk;
   end
`endif 
   
   /********************** UART receiver **************************/

`ifdef NRV_IO_UART_RX
   
   reg serial_valid_latched = 1'b0;
   wire serial_valid;
   wire [7:0] serial_rx_data;
   reg  [7:0] serial_rx_data_latched;
   rxuart rxUART( 
       .clk(clk),
       .resetq(1'b1),       
       .uart_rx(RXD),
       .rd(1'b1),
       .valid(serial_valid),
       .data(serial_rx_data) 
   );

   always @(posedge clk) begin
      if(serial_valid) begin
         serial_rx_data_latched <= serial_rx_data;
	 serial_valid_latched <= 1'b1;
      end
      if(rd && address == UART_RX_DAT_address) begin
         serial_valid_latched <= 1'b0;
      end
   end
   
`endif

   /********************** UART transmitter ***************************/

`ifdef NRV_IO_UART_TX
   
   wire       serial_tx_busy;
   wire       serial_tx_wr;
   uart txUART(
       .clk(clk),
       .uart_tx(TXD),	       
       .resetq(1'b1),
       .uart_busy(serial_tx_busy),
       .uart_wr_i(serial_tx_wr),
       .uart_dat_i(in[7:0])		 
   );

`endif   

   /********************** MAX2719 led matrix driver *******************/
   
`ifdef NRV_IO_MAX2719
   reg [2:0]  MAX2719_divider;
   always @(posedge clk) begin
      MAX2719_divider <= MAX2719_divider + 1;
   end
   // clk=60MHz, slow_clk=60/8 MHz (max = 10 MHz)
   wire       MAX2719_slow_clk = (MAX2719_divider == 3'b000);
   reg[4:0]   MAX2719_bitcount; // 0 means idle
   reg[15:0]  MAX2719_shifter;

   assign MAX2719_DIN  = MAX2719_shifter[15];
   wire MAX2719_sending = |MAX2719_bitcount;
   assign MAX2719_CS  = !MAX2719_sending;
   assign MAX2719_CLK = MAX2719_sending && MAX2719_slow_clk;
`endif   
   
   /********************* Decoder for IO read **************************/
   
   always @(*) begin
      (* parallel_case, full_case *)
      case(address)
`ifdef NRV_IO_LEDS      
	LEDs_address:         out = {28'b0, LEDs};
`endif
`ifdef NRV_IO_SSD1351
	SSD1351_CNTL_address: out = {31'b0, SSD1351_sending};
`endif
`ifdef NRV_IO_UART_RX
	UART_RX_CNTL_address: out = {31'b0, serial_valid_latched}; 
	UART_RX_DAT_address:  out = serial_rx_data_latched;
`endif
`ifdef NRV_IO_UART_TX
	UART_TX_CNTL_address: out = {31'b0, serial_tx_busy}; 	
`endif
`ifdef NRV_IO_MAX2719
	MAX2719_CNTL_address: out = {31'b0, MAX2719_sending};
`endif	
	default: out = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ;
      endcase
   end

   /********************* Multiplexer for IO write *********************/

   always @(posedge clk) begin
      if(wr) begin
	 case(address)
`ifdef NRV_IO_LEDS	   
	   LEDs_address: begin
	      LEDs <= in[3:0];
	      `bench($display("************************** LEDs = %b", in[3:0]));
	      `bench($display(" in = %h  %d  %b", in, $signed(in),in));
	   end
`endif
`ifdef NRV_IO_SSD1351	   
	   SSD1351_CNTL_address: begin
	      { SSD1351_RST, SSD1351_special } <= in[1:0];
	   end
	   SSD1351_CMD_address: begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b0;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
	   SSD1351_DAT_address: begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b1;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
`endif 
`ifdef NRV_IO_MAX2719
	   MAX2719_DAT_address: begin
	      MAX2719_shifter <= in[15:0];
	      MAX2719_bitcount <= 16;
	   end
`endif	   
	 endcase 
      end else begin // if (wr)
`ifdef NRV_IO_SSD1351	   	 
	 if(SSD1351_sending && !SSD1351_slow_clk) begin
            SSD1351_bitcount <= SSD1351_bitcount - 4'd1;
            SSD1351_shifter <= {SSD1351_shifter[6:0], 1'b0};
	 end
`endif
`ifdef NRV_IO_MAX2719
	 if(MAX2719_sending &&  MAX2719_slow_clk) begin
            MAX2719_bitcount <= MAX2719_bitcount - 5'd1;
            MAX2719_shifter <= {MAX2719_shifter[14:0], 1'b0};
	 end
`endif	   	 	 
      end 
   end

`ifdef NRV_IO_UART_TX
  assign serial_tx_wr = (wr && address == UART_TX_DAT_address);
`endif  
   
endmodule


/********************* Nrv main *******************************/

module nanorv(
// `ifdef NRV_IO_LEDS	      
   output D1,D2,D3,D4,D5,
//`endif	      
`ifdef NRV_IO_SSD1351	      
   output oled_DIN, oled_CLK, oled_CS, oled_DC, oled_RST,
`endif
`ifdef NRV_IO_UART_RX	      
   input  RXD,
`endif
`ifdef NRV_IO_UART_TX	      	      
   output TXD,
`endif	      
`ifdef NRV_IO_MAX2719	   
   output ledmtx_DIN, ledmtx_CS, ledmtx_CLK,
`endif
`ifdef NRV_RESET	      
   input  RESET,
`endif	      
   input  pclk
);

  wire  clk;
   
 `ifdef BENCH
   assign clk = pclk;
 `else   
   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      //.DIVF(7'b0110100), .DIVQ(3'b011), // 80 MHz
      //.DIVF(7'b0110001), .DIVQ(3'b011), // 75 MHz
      .DIVF(7'b1001111), .DIVQ(3'b100), // 60 MHz
      //.DIVF(7'b0110100), .DIVQ(3'b100), // 40 MHz
      //.DIVF(7'b1001111), .DIVQ(3'b101), // 30 MHz
      .FILTER_RANGE(3'b001),
   ) pll (
      .REFERENCECLK(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );
 `endif

   reg [6:0] reset_cnt = 0;
   wire       reset = &reset_cnt;
   always @(posedge clk, negedge RESET) begin
      if(!RESET) begin
	 reset_cnt <= 0;
      end else begin
	 reset_cnt <= reset_cnt + !reset;
      end
   end
   

  wire [31:0] address;
  wire        error;
  
  // Memory-mapped IOs 
  wire [31:0] IOin;
  wire [31:0] IOout;
  wire        IOrd;
  wire        IOwr;
  wire [7:0]  IOaddress;
  NrvIO IO(
     .in(IOin),
     .out(IOout),
     .rd(IOrd),
     .wr(IOwr),
     .address(IOaddress),
`ifdef NRV_IO_LEDS	   
     .LEDs({D4,D3,D2,D1}),
`endif
`ifdef NRV_IO_SSD1351	   
     .SSD1351_DIN(oled_DIN),
     .SSD1351_CLK(oled_CLK),
     .SSD1351_CS(oled_CS),
     .SSD1351_DC(oled_DC),
     .SSD1351_RST(oled_RST),
`endif
`ifdef NRV_IO_UART_RX	   
     .RXD(RXD),
`endif
`ifdef NRV_IO_UART_TX	   
     .TXD(TXD),
`endif	   
`ifdef NRV_IO_MAX2719	   
     .MAX2719_DIN(ledmtx_DIN),
     .MAX2719_CS(ledmtx_CS),
     .MAX2719_CLK(ledmtx_CLK),
`endif
     .clk(clk)
  );
   
  wire [31:0] dataIn;
  wire [31:0] dataOut;
  wire        dataRd;
  wire [3:0]  dataWrByteMask;
   
  NrvMemoryInterface Memory(
    .clk(clk),
    .address(address[13:0]),
    .in(dataOut),
    .out(dataIn),
    .rd(dataRd),
    .wrByteMask(dataWrByteMask),
    .IOin(IOout),
    .IOout(IOin),
    .IOrd(IOrd),
    .IOwr(IOwr),
    .IOaddress(IOaddress)	      
  );

  NrvProcessor processor(
    .clk(clk),			
    .address(address),
    .dataIn(dataIn),
    .dataOut(dataOut),
    .dataRd(dataRd),
    .dataWrByteMask(dataWrByteMask),
    .reset(reset),
    .error(error)
  );
   
`ifdef NRV_IO_LEDS  
     assign D5 = error;
`endif

endmodule


