/**
 * Step 10: Creating a RISC-V processor
 *         LUI and AUIPC
 * Usage:
 *    iverilog step10.v
 *    vvp a.out
 *    to exit: <ctrl><c> then finish
 */

`default_nettype none

module RiscV (
    input clock,
    output [4:0] leds
);
   assign leds = 0; // we will use the LEDs later
   
   reg [31:0] ROM [0:255]; 
   reg [31:0] PC;          // program counter
   reg [31:0] instr;       // current instruction


`include "riscv_assembly.v"

   // Initial value of program counter and instruction
   // register.
   initial begin
      PC = 0;
      instr = NOP_CODEOP;
   end

   // ROM initialization, using our poor's men assembly
   // in "risc_assembly.v".
   initial begin
      LUI(x1, 32'b11111111111111111111111111111111); // Just takes the 20 MSBs (12 LSBs ignored)
      ORI(x1, x1, 32'b11111111111111111111111111111111); // Sets the 12 LSBs (20 MSBs ignored)
      EBREAK();
   end

   
   // See the table P. 105 in RISC-V manual
   // The 10 RISC-V instructions
   // Funny: what we do here is in fact just the reverse
   // of what's done in riscv_assembly.v !
   
   wire isALUreg  =  (instr[6:0] == 7'b0110011); // rd <- rs1 OP rs2   
   wire isALUimm  =  (instr[6:0] == 7'b0010011); // rd <- rs1 OP Iimm
   wire isBranch  =  (instr[6:0] == 7'b1100011); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:0] == 7'b1100111); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:0] == 7'b1101111); // rd <- PC+4; PC<-PC+Jimm
   wire isAUIPC   =  (instr[6:0] == 7'b0010111); // rd <- PC + Uimm
   wire isLUI     =  (instr[6:0] == 7'b0110111); // rd <- Uimm   
   wire isLoad    =  (instr[6:0] == 7'b0000011); // rd <- mem[rs1+Iimm]
   wire isStore   =  (instr[6:0] == 7'b0100011); // mem[rs1+Simm] <- rs2
   wire isSYSTEM  =  (instr[6:0] == 7'b1110011); // special

   // The 5 immediate formats
   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

   // Source and destination registers
   wire [4:0] rs1Id = instr[19:15];
   wire [4:0] rs2Id = instr[24:20];
   wire [4:0] rdId  = instr[11:7];
   
   // function codes
   wire [2:0] funct3 = instr[14:12];
   wire [6:0] funct7 = instr[31:25];
   
   // The registers bank
   reg [31:0] RegisterBank [0:31];
   reg [31:0] rs1; // value of source
   reg [31:0] rs2; //  registers.
   wire [31:0] writeBackData; // data to be written to rd
   wire        writeBackEn;   // asserted if data should be written to rd

   integer     i;
   initial begin
      for(i=0; i<32; ++i) begin
	 RegisterBank[i] = 0;
      end
   end

   // The ALU
   wire [31:0] aluIn1 = rs1;
   wire [31:0] aluIn2 = isALUreg ? rs2 : Iimm;
   reg [31:0] aluOut;
   wire [4:0] shamt = isALUreg ? rs2[4:0] : instr[24:20]; // shift amount

   always @(*) begin
      case(funct3)
	3'b000: aluOut = (funct7[5] & instr[5]) ? (aluIn1 - aluIn2) : (aluIn1 + aluIn2);
	3'b001: aluOut = aluIn1 << shamt;
	3'b010: aluOut = ($signed(aluIn1) < $signed(aluIn2));
	3'b011: aluOut = (aluIn1 < aluIn2);
	3'b100: aluOut = (aluIn1 ^ aluIn2);
	3'b101: aluOut = funct7[5]? ($signed(aluIn1) >>> shamt) : ($signed(aluIn1) >> shamt); 
	3'b110: aluOut = (aluIn1 | aluIn2);
	3'b111: aluOut = (aluIn1 & aluIn2);	
      endcase
   end

   // ADD/SUB/ADDI: 
   // funct7[5] is 1 for SUB and 0 for ADD. We need also to test instr[5]
   // to make the difference with ADDI
   //
   // SRLI/SRAI/SRL/SRA: 
   // funct7[5] is 1 for arithmetic shift (SRA/SRAI) and 0 for logical shift (SRL/SRLI)

   reg takeBranch;
   always @(*) begin
      case(funct3)
	3'b000: takeBranch = (rs1 == rs2);
	3'b001: takeBranch = (rs1 != rs2);
	3'b100: takeBranch = ($signed(rs1) < $signed(rs2));
	3'b101: takeBranch = ($signed(rs1) >= $signed(rs2));
	3'b110: takeBranch = (rs1 < rs2);
	3'b110: takeBranch = (rs1 >= rs2);
	default: takeBranch = 1'b0;
      endcase
   end
   
   // The state machine
   localparam FETCH_INSTR = 0;
   localparam FETCH_REGS  = 1;
   localparam EXECUTE     = 2;
   reg [1:0] state;

   // register write back
   assign writeBackData = 
			  (isJAL || isJALR) ? (PC + 4) :
			  (isLUI) ? Uimm :
			  (isAUIPC) ? (PC + Uimm) : 
			  aluOut;
   assign writeBackEn = (state == EXECUTE && (isALUreg || isALUimm || isJAL || isJALR || isLUI || isAUIPC));

   // next PC
   wire [31:0] nextPC = 
          (isBranch && takeBranch) ? PC+Bimm :
	  isJAL  ? PC+Jimm :
	  isJALR ? rs1+Iimm :
	  PC+4;
   
   initial begin
      state = FETCH_INSTR;
   end

   always @(posedge clock) begin
      case(state)
	FETCH_INSTR: begin
	   instr <= ROM[PC[31:2]];
	   state <= FETCH_REGS;
	end
	FETCH_REGS: begin
	   rs1 <= RegisterBank[rs1Id];
	   rs2 <= RegisterBank[rs2Id];
	   state <= EXECUTE;
	end
	EXECUTE: begin
	   case (1'b1)
	     isALUreg: $display(
				"ALUreg rd=%d rs1=%d rs2=%d funct3=%b",
				rdId, rs1Id, rs2Id, funct3
		       );
	     isALUimm: $display(
				"ALUimm rd=%d rs1=%d imm=%0d funct3=%b",
				rdId, rs1Id, Iimm, funct3
		       );
	     isBranch: $display(
				"BRANCH rs1=%d rs2=%d takeBranch=%b",
				rs1Id, rs2Id, takeBranch
		       );
	     isJAL:    $display("JAL");
	     isJALR:   $display("JALR");
	     isAUIPC:  $display("AUIPC");
	     isLUI:    $display("LUI");	
	     isLoad:   $display("LOAD");
	     isStore:  $display("STORE");
	     isSYSTEM: $display("SYSTEM");
	   endcase 
	   if(isSYSTEM) begin
	      $finish();
	   end
	   PC <= nextPC;
	   state <= FETCH_INSTR;
	end
      endcase 

      if(writeBackEn && rdId != 0) begin
	 RegisterBank[rdId] <= writeBackData;
	 $display("x%0d <= %b",rdId,writeBackData);
      end
      
      
   end
endmodule

module bench();
   reg clock;
   wire [4:0] leds;

   RiscV uut(
     .clock(clock),
     .leds(leds)	     
   );
   
   initial begin
      clock = 0;
      forever begin
	 #1 clock = ~clock;
	 // $display("LEDS=%b",leds); // we will use the LEDs later
      end
   end
   
endmodule   
   
