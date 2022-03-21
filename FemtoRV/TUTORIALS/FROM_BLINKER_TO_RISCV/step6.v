/**
 * Step 6: Creating a RISC-V processor
 *         The ALU
 */

`default_nettype none

module SOC (
    input clock,
    output leds_active,
    output [4:0] leds
);
   // we will use the LEDs later...
   assign leds = 5'b0; 
   assign leds_active = 1'b0;
   
   reg [31:0] ROM [0:255]; 
   reg [31:0] PC;          // program counter
   reg [31:0] instr;       // current instruction

   initial begin
      PC = 0;
      
      // add x0, x0, x0
      //                   rs2   rs1  add  rd   ALUREG
      instr = 32'b0000000_00000_00000_000_00000_0110011;
      // add x1, x0, x0
      //                    rs2   rs1  add  rd   ALUREG
      ROM[0] = 32'b0000000_00000_00000_000_00001_0110011;
      // addi x1, x1, 1
      //             imm         rs1  add  rd   ALUIMM
      ROM[1] = 32'b000000000001_00001_000_00001_0010011;
      // addi x1, x1, 1
      //             imm         rs1  add  rd   ALUIMM
      ROM[2] = 32'b000000000001_00001_000_00001_0010011;
      // addi x1, x1, 1
      //             imm         rs1  add  rd   ALUIMM
      ROM[3] = 32'b000000000001_00001_000_00001_0010011;
      // addi x1, x1, 1
      //             imm         rs1  add  rd   ALUIMM
      ROM[4] = 32'b000000000001_00001_000_00001_0010011;
      // add x2, x1, x0
      //                    rs2   rs1  add  rd   ALUREG
      ROM[5] = 32'b0000000_00000_00001_000_00010_0110011;
      // add x3, x1, x2
      //                    rs2   rs1  add  rd   ALUREG
      ROM[6] = 32'b0000000_00010_00001_000_00011_0110011;
      // srli x3, x3, 3
      //                   shamt   rs1  sr  rd   ALUIMM
      ROM[7] = 32'b0000000_00011_00011_101_00011_0010011;
      // slli x3, x3, 31
      //                   shamt   rs1  sl  rd   ALUIMM
      ROM[8] = 32'b0000000_11111_00011_001_00011_0010011;
      // srai x3, x3, 5
      //                   shamt   rs1  sr  rd   ALUIMM
      ROM[9] = 32'b0100000_00101_00011_101_00011_0010011;
      
      ROM[10] = 0;
   end

   
   // See the table P. 105 in RISC-V manual
   
   // The 10 RISC-V instructions
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
   
   // The state machine
   localparam FETCH_INSTR = 0;
   localparam FETCH_REGS  = 1;
   localparam EXECUTE     = 2;
   reg [1:0] state;

   // register write back
   assign writeBackData = aluOut; 
   assign writeBackEn = (state == EXECUTE && (isALUreg || isALUimm));   
   
   initial begin
      state = FETCH_INSTR;
   end

   always @(posedge clock) begin
      case(state)
	FETCH_INSTR: begin
	   instr <= ROM[PC];
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
	     isBranch: $display("BRANCH");
	     isJAL:    $display("JAL");
	     isJALR:   $display("JALR");
	     isAUIPC:  $display("AUIPC");
	     isLUI:    $display("LUI");	
	     isLoad:   $display("LOAD");
	     isStore:  $display("STORE");
	     isSYSTEM: $display("SYSTEM");
	   endcase 
	   if(instr == 0) begin
	      $finish();
	   end
	   PC <= PC + 1;
	   state <= FETCH_INSTR;
	end
      endcase 

      if(writeBackEn && rdId != 0) begin
	 RegisterBank[rdId] <= writeBackData;
	 $display("x%0d <= %b",rdId,writeBackData);
      end
      
      
   end
endmodule

