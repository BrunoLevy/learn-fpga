/**
 * Step 14: Creating a RISC-V processor
 *         Playing with more interesting programs
 *         Multiplication routine.
 */

`default_nettype none


module Memory (
   input clock,
   input      [31:0] mem_addr,  
   output reg [31:0] mem_rdata, 
   input   	     mem_rstrb,
   input      [31:0] mem_wdata,
   input      [3:0]  mem_wmask	       
);

   reg [31:0] MEM [0:1023];

`include "riscv_assembly.v"
   
   initial begin
       mem_rdata = 0;
   end
   
   
   // MEM initialization, using our poor's men assembly
   // in "risc_assembly.v".

   integer mulsi3 = 400;
   
   initial begin

      L2_ = 420;
      
      // LI(sp,4096)
      // Stack pointer: end of RAM
      ADDI(sp,x0,1);
      SLLI(sp,sp,12);

      // LI(gp, 8192)
      // General pointer: IO page
      //      SW(a0,gp,4); -> displays character
      //      SW(a0,gp,8); -> displays number
      ADDI(gp,x0,1);
      SLLI(gp,gp,13);
      
      LI(a0,8);
      SW(a0,gp,8);
      LI(a1,9);
      SW(a1,gp,8);
      CALL(LabelRef(mulsi3));
      SW(a0,gp,8);
      EBREAK();

      // Mutiplication routine,
      // Input in a0 and a1
      // Result in a0
      memPC = mulsi3;
      ADD(a2,a0,zero);
      LI(a0,0);
Label(L1_); 
      ANDI(a3,a1,1);
      BEQ(a3,zero,LabelRef(L2_)); 
      ADD(a0,a0,a2);
Label(L2_);
      SRLI(a1,a1,1);
      SLLI(a2,a2,1);
      BNE(a1,zero,LabelRef(L1_));
      RET();

      if(ASMerror) begin
	 $finish();
      end
   end

   wire [29:0] word_addr = mem_addr[31:2];
   wire        isIO = mem_addr[13];
   
   always @(posedge clock) begin
      if(isIO) begin
	 if(|mem_wmask) begin
	    if(word_addr[0]) begin
	       $write("%c",mem_wdata[7:0]);
	       $fflush(32'h8000_0001);
	    end
	    if(word_addr[1]) begin
	       $display("Output: %b %0d %0d",mem_wdata, mem_wdata, $signed(mem_wdata));
	    end
	 end
      end else begin
	 if(mem_rstrb) begin
            mem_rdata <= MEM[word_addr];
	 end
	 if(mem_wmask[0]) MEM[word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
	 if(mem_wmask[1]) MEM[word_addr][15:8 ] <= mem_wdata[15:8 ];
	 if(mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
	 if(mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];
      end
   end
   
endmodule


module RiscV (
    input clock,
    output    [31:0] mem_addr,  
    input     [31:0] mem_rdata, 
    output 	     mem_rstrb,
    output    [31:0] mem_wdata,
    output     [3:0] mem_wmask	       
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
   // ------------------------------------------------------------------------
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

   // Store
   // ------------------------------------------------------------------------

   assign mem_wdata[ 7: 0] = rs2[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  :
			     loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on loadstore_addr[1:0])

   wire [3:0] STORE_wmask =
	      mem_byteAccess      ?
	            (loadstore_addr[1] ?
		          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
		          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
	      mem_halfwordAccess ?
	            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   assign mem_wmask = {4{(state == STORE)}} & STORE_wmask;
   
   // The state machine
   localparam FETCH_INSTR = 0;
   localparam WAIT_INSTR  = 1;
   localparam FETCH_REGS  = 2;
   localparam EXECUTE     = 3;
   localparam LOAD        = 4;
   localparam WAIT_DATA   = 5;
   localparam STORE       = 6;
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
	   /*
	   case (1'b1)
	     isALUreg: $display(
				"%d ALUreg rd=%d rs1=%d rs2=%d funct3=%b",
				PC, rdId, rs1Id, rs2Id, funct3
		       );
	     isALUimm: $display(
				"%d ALUimm rd=%d rs1=%d imm=%0d funct3=%b",
				PC, rdId, rs1Id, Iimm, funct3
		       );
	     isBranch: $display(
				"%d BRANCH rs1=%d rs2=%d takeBranch=%b",
				PC, rs1Id, rs2Id, takeBranch
		       );
	     isJAL:    $display("%d JAL",PC);
	     isJALR:   $display("%d JALR",PC);
	     isAUIPC:  $display("%d AUIPC",PC);
	     isLUI:    $display("%d LUI",PC);	
	     isLoad:   $display("%d LOAD",PC);
	     isStore:  $display("%d STORE",PC);
	     isSYSTEM: $display("%d SYSTEM",PC);
	   endcase 
	   */
	   if(isSYSTEM) begin
	      $finish();
	   end
	   PC <= nextPC;
	   loadstore_addr <= isStore ? rs1 + Simm : rs1 + Iimm;
	   state <= isLoad  ? LOAD  : 
		    isStore ? STORE : 
		    FETCH_INSTR;
	end 

	LOAD: begin
	   state <= WAIT_DATA;
	end

	STORE: begin
//	   $display("STORE addr=%0d rs1=%d rs2=%d Simm=%b",loadstore_addr, rs1, rs2, Simm);
	   state <= FETCH_INSTR;
	end

	WAIT_DATA: begin
	   state <= FETCH_INSTR;
	end
      endcase 

      if(writeBackEn && rdId != 0) begin
	 RegisterBank[rdId] <= writeBackData;
	 // $display("x%0d <= %b %0d %0d",rdId,writeBackData,writeBackData,$signed(writeBackData));
      end
      
   end

   assign mem_addr = (state == WAIT_INSTR || state == FETCH_INSTR) ?
		     PC : loadstore_addr ;
   assign mem_rstrb = (state == FETCH_INSTR || state == LOAD);
      
endmodule

module SOC(
    input clock,
    output leds_active,
    output [4:0] leds
);
   // we will use the LEDs later...
   assign leds = 5'b0; 
   assign leds_active = 1'b0;

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
   
