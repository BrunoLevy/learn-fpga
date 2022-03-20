/**
 * Step 13: Creating a RISC-V processor
 *         Store (WIP)
 * Usage:
 *    iverilog step13.v
 *    vvp a.out
 *    to exit: <ctrl><c> then finish
 */

`default_nettype none


module Memory (
   input clock,
   input      [31:0] mem_addr,  
   output reg [31:0] mem_rdata, 
   input   	     mem_rstrb,
   input      [31:0] mem_wdata,
   output     [3:0]  mem_wmask	       
);

   reg [31:0] MEM [0:255]; 

`include "riscv_assembly.v"
   
   initial begin
       mem_rdata = 0;
   end
   
   
   // MEM initialization, using our poor's men assembly
   // in "risc_assembly.v".
   initial begin
                  ADD(x1,x0,x0);      
                  ADDI(x2,x0,16);
      Label(L0_); LB(x3,x1,400);
                  ADDI(x1,x1,1); 
                  BNE(x1,x2, LabelRef(L0_));
                  EBREAK();
      
      MEM[100] = {8'h4, 8'h3, 8'h2, 8'h1};
      MEM[101] = {8'h8, 8'h7, 8'h6, 8'h5};
      MEM[102] = {8'hc, 8'hb, 8'ha, 8'h9};
      MEM[103] = {8'h0, 8'hf, 8'he, 8'hd};            
   end

   wire [29:0] word_addr = mem_addr[31:2];
   
   always @(posedge clock) begin
      if(mem_rstrb) begin
         mem_rdata <= MEM[word_addr];
      end
      if(mem_wmask[0]) MEM[word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1]) MEM[word_addr][15:8 ] <= mem_wdata[15:8 ];
      if(mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
      if(mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];	 
   end
   
endmodule


module RiscV (
    input clock,
    output    [31:0] mem_addr,  
    input     [31:0] mem_rdata, 
    output 	     mem_rstrb,
    output    [31:0] mem_wdata,
    input     [3:0]  mem_wmask	       
);
   
   reg [31:0] PC;          // program counter
   reg [31:0] instr;       // current instruction

   // add x0,x0,x0   
   localparam [31:0] NOP_CODEOP = 32'b0000000_00000_00000_000_00000_0110011; 

   // Initial value of program counter and instruction
   // register.
   initial begin
      PC = 0;
      instr = NOP_CODEOP;
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

   reg [31:0] loadstore_addr;
   
   // Load
   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned halfword
   // and byte load/store, based on:
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   wire mem_byteAccess     = funct3[1:0] == 2'b00;
   wire mem_halfwordAccess = funct3[1:0] == 2'b01;


   wire [15:0] LOAD_halfword =
	       loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   wire  [7:0] LOAD_byte =
	       loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion
   wire LOAD_sign =
	!funct3[2] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;


   
   // The state machine
   localparam FETCH_INSTR = 0;
   localparam WAIT_INSTR  = 1;
   localparam FETCH_REGS  = 2;
   localparam EXECUTE     = 3;
   localparam LOAD        = 4;
   localparam WAIT_DATA   = 5;
   reg [2:0] state;

   // register write back
   assign writeBackData = 
			  (isJAL || isJALR) ? (PC + 4) :
			  (isLUI) ? Uimm :
			  (isAUIPC) ? (PC + Uimm) :
			  (isLoad)  ? LOAD_data :
			  aluOut;
   assign writeBackEn = 
			(state == EXECUTE && 
			   (isALUreg || 
			    isALUimm || 
			    isJAL    || 
			    isJALR   || 
			    isLUI    || 
			    isAUIPC)
			 ) || (state == WAIT_DATA);

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
	   state <= WAIT_INSTR;
	end
	WAIT_INSTR: begin
	   instr <= mem_rdata;
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
	   loadstore_addr <= rs1 + Iimm;
	   state <= isLoad ? LOAD : FETCH_INSTR;
	end 

	LOAD: begin
	   state <= WAIT_DATA;
	end

	WAIT_DATA: begin
	   state <= FETCH_INSTR;
	end
      endcase 

      if(writeBackEn && rdId != 0) begin
	 RegisterBank[rdId] <= writeBackData;
	 $display("x%0d <= %b",rdId,writeBackData);
      end
      
   end

   assign mem_addr = (state == WAIT_INSTR || state == FETCH_INSTR) ?
		     PC : loadstore_addr ;
   assign mem_rstrb = (state == FETCH_INSTR || state == LOAD);
      
endmodule

module SOC(
    input clock,
    output [4:0] leds
);
   assign leds = 0;

   wire [31:0] mem_addr;
   wire [31:0] mem_rdata;
   wire mem_rstrb;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;
   
   Memory RAM(
      .clock(clock),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask)	      
   );

   RiscV CPU(
      .clock(clock),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .mem_wdata(mem_wdata),
      .mem_wmask(mem_wmask)	      
   );
   
endmodule


module bench();
   reg clock;
   wire [4:0] leds;
   
   SOC uut(
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
   
