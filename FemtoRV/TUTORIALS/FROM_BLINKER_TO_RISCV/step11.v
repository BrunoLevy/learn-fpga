/**
 * Step 11: Creating a RISC-V processor
 *         Separate memory
 * DONE*
 */

`default_nettype none
`include "clockworks.v"

module Memory (
   input             clk,
   input      [31:0] mem_addr,  // address to be read
   output reg [31:0] mem_rdata, // data read from memory
   input   	     mem_rstrb  // goes high when processor wants to read
);

   reg [31:0] MEM [0:255]; 

`include "riscv_assembly.v"
   integer L0_=8;
   initial begin
                  ADD(x1,x0,x0);      
                  ADDI(x2,x0,31);
      Label(L0_); 
                  ADDI(x1,x1,1); 
                  BNE(x1, x2, LabelRef(L0_));
                  EBREAK();
      endASM();
   end

   always @(posedge clk) begin
      if(mem_rstrb) begin
         mem_rdata <= MEM[mem_addr[31:2]];
      end
   end
endmodule


module Processor (
    input 	      clk,
    input 	      resetn,
    output     [31:0] mem_addr, 
    input      [31:0] mem_rdata, 
    output 	      mem_rstrb,
    output reg [31:0] x1		  
);

   reg [31:0] PC=0;        // program counter
   reg [31:0] instr;       // current instruction

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

`ifdef BENCH   
   integer     i;
   initial begin
      for(i=0; i<32; ++i) begin
	 RegisterBank[i] = 0;
      end
   end
`endif   

   // The ALU
   wire [31:0] aluIn1 = rs1;
   wire [31:0] aluIn2 = isALUreg ? rs2 : Iimm;
   reg [31:0] aluOut;
   wire [4:0] shamt = isALUreg ? rs2[4:0] : instr[24:20]; // shift amount

   // ADD/SUB/ADDI: 
   // funct7[5] is 1 for SUB and 0 for ADD. We need also to test instr[5]
   // to make the difference with ADDI
   //
   // SRLI/SRAI/SRL/SRA: 
   // funct7[5] is 1 for arithmetic shift (SRA/SRAI) and 
   // 0 for logical shift (SRL/SRLI)
   always @(*) begin
      case(funct3)
	3'b000: aluOut = (funct7[5] & instr[5]) ? 
			 (aluIn1 - aluIn2) : (aluIn1 + aluIn2);
	3'b001: aluOut = aluIn1 << shamt;
	3'b010: aluOut = ($signed(aluIn1) < $signed(aluIn2));
	3'b011: aluOut = (aluIn1 < aluIn2);
	3'b100: aluOut = (aluIn1 ^ aluIn2);
	3'b101: aluOut = funct7[5]? ($signed(aluIn1) >>> shamt) : 
			 ($signed(aluIn1) >> shamt); 
	3'b110: aluOut = (aluIn1 | aluIn2);
	3'b111: aluOut = (aluIn1 & aluIn2);	
      endcase
   end


   // The predicate for branch instructions
   reg takeBranch;
   always @(*) begin
      case(funct3)
	3'b000: takeBranch = (rs1 == rs2);
	3'b001: takeBranch = (rs1 != rs2);
	3'b100: takeBranch = ($signed(rs1) < $signed(rs2));
	3'b101: takeBranch = ($signed(rs1) >= $signed(rs2));
	3'b110: takeBranch = (rs1 < rs2);
	3'b111: takeBranch = (rs1 >= rs2);
	default: takeBranch = 1'b0;
      endcase
   end
   
   // The state machine
   localparam FETCH_INSTR = 0;
   localparam WAIT_INSTR  = 1;
   localparam FETCH_REGS  = 2;
   localparam EXECUTE     = 3;
   reg [1:0] state = FETCH_INSTR;

   // register write back
   assign writeBackData = (isJAL || isJALR) ? (PC + 4) :
			  (isLUI) ? Uimm :
			  (isAUIPC) ? (PC + Uimm) : 
			  aluOut;
   
   assign writeBackEn = (state == EXECUTE && 
			 (isALUreg || 
			  isALUimm || 
			  isJAL    || 
			  isJALR   ||
			  isLUI    ||
			  isAUIPC)
			 );
   // next PC
   wire [31:0] nextPC = (isBranch && takeBranch) ? PC+Bimm  :	       
   	                isJAL                    ? PC+Jimm  :
	                isJALR                   ? rs1+Iimm :
	                PC+4;
   
   always @(posedge clk) begin
      if(!resetn) begin
	 PC    <= 0;
	 state <= FETCH_INSTR;
      end else begin
	 if(writeBackEn && rdId != 0) begin
	    RegisterBank[rdId] <= writeBackData;
	    // For displaying what happens.
	    if(rdId == 1) begin
	       x1 <= writeBackData;
	    end
`ifdef BENCH	 
	    $display("x%0d <= %b",rdId,writeBackData);
`endif	 
	 end
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
	      if(!isSYSTEM) begin
		 PC <= nextPC;
	      end
	      state <= FETCH_INSTR;
`ifdef BENCH      
	      if(isSYSTEM) $finish();
`endif      
	   end
	 endcase 
      end
   end

   assign mem_addr = PC;
   assign mem_rstrb = (state == FETCH_INSTR);
   
`ifdef BENCH
   always @(posedge clk) begin
      if(state == FETCH_REGS) begin
	 case (1'b1)
	   isALUreg: $display(
			      "ALUreg rd=%d rs1=%d rs2=%d funct3=%b",
			      rdId, rs1Id, rs2Id, funct3
			      );
	   isALUimm: $display(
			      "ALUimm rd=%d rs1=%d imm=%0d funct3=%b",
			      rdId, rs1Id, Iimm, funct3
			      );
	   isBranch: $display("BRANCH rs1=%0d rs2=%0d",rs1Id, rs2Id);
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
      end 
   end
`endif	      
   
endmodule


module SOC (
    input  CLK,        // system clock 
    input  RESET,      // reset button
    output [4:0] LEDS, // system LEDs
    input  RXD,        // UART receive
    output TXD         // UART transmit
);

   wire    clk;
   wire    resetn;

   Memory RAM(
      .clk(clk),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb)
   );

   wire [31:0] mem_addr;
   wire [31:0] mem_rdata;
   wire mem_rstrb;
   wire [31:0] x1;

   Processor CPU(
      .clk(clk),
      .resetn(resetn),		 
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_rstrb(mem_rstrb),
      .x1(x1)		 
   );
   assign LEDS = x1[4:0];

   // Gearbox and reset circuitry.
   Clockworks #(
     .SLOW(19) // Divide clock frequency by 2^19
   )CW(
     .CLK(CLK),
     .RESET(RESET),
     .clk(clk),
     .resetn(resetn)
   );
   
   assign TXD  = 1'b0; // not used for now   

endmodule

