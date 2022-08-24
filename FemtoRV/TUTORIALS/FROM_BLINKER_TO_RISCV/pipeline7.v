/**
 * pipeline6.v
 * Let us see how to morph our multi-cycle CPU into a pipelined CPU !
 * Step 7: Simplifying it, making it synthesizable
 * (does not synthesize for now, still investigating...)
 */
 
`default_nettype none
`include "clockworks.v"
`include "emitter_uart.v"

/******************************************************************************/

module Processor (
    input 	  clk,
    input 	  resetn,
    output [31:0] IO_mem_addr,  // IO memory address
    input [31:0]  IO_mem_rdata, // data read from IO memory
    output [31:0] IO_mem_wdata, // data written to IO memory
    output        IO_mem_wr     // IO write flag
);

`include "riscv_disassembly.v"

/******************************************************************************/

 /* 
   Reminder for the 10 RISC-V codeops
   ----------------------------------
   7'b0110011 | ALUreg  | rd <- rs1 OP rs2   
   7'b0010011 | ALUimm  | rd <- rs1 OP Iimm
   7'b1100011 | Branch  | if(rs1 OP rs2) PC<-PC+Bimm
   7'b1100111 | JALR    | rd <- PC+4; PC<-rs1+Iimm
   7'b1101111 | JAL     | rd <- PC+4; PC<-PC+Jimm
   7'b0010111 | AUIPC   | rd <- PC + Uimm
   7'b0110111 | LUI     | rd <- Uimm   
   7'b0000011 | Load    | rd <- mem[rs1+Iimm]
   7'b0100011 | Store   | mem[rs1+Simm] <- rs2
   7'b1110011 | SYSTEM  | special
 */

/******************************************************************************/

   /* Instruction decoder as functions (we will use them several times) */

   /* The 10 "recognizers" for the 10 codeops */
   function isALUreg; input [31:0] I; isALUreg=(I[6:2]==5'b01100); endfunction
   function isALUimm; input [31:0] I; isALUimm=(I[6:2]==5'b00100); endfunction
   function isBranch; input [31:0] I; isBranch=(I[6:2]==5'b11000); endfunction
   function isJALR;   input [31:0] I; isJALR  =(I[6:2]==5'b11001); endfunction
   function isJAL;    input [31:0] I; isJAL   =(I[6:2]==5'b11011); endfunction
   function isAUIPC;  input [31:0] I; isAUIPC =(I[6:2]==5'b00101); endfunction
   function isLUI;    input [31:0] I; isLUI   =(I[6:2]==5'b01101); endfunction
   function isLoad;   input [31:0] I; isLoad  =(I[6:2]==5'b00000); endfunction
   function isStore;  input [31:0] I; isStore =(I[6:2]==5'b01000); endfunction
   function isSYSTEM; input [31:0] I; isSYSTEM=(I[6:2]==5'b11100); endfunction
   
   /* Register indices */
   function [4:0] rs1Id; input [31:0] I; rs1Id = I[19:15];      endfunction
   function [4:0] rs2Id; input [31:0] I; rs2Id = I[24:20];      endfunction
   function [4:0] shamt; input [31:0] I; shamt = I[24:20];      endfunction   
   function [4:0] rdId;  input [31:0] I; rdId  = I[11:7];       endfunction
   function [1:0] csrId; input [31:0] I; csrId = {I[27],I[21]}; endfunction

   /* funct3 and funct7 */
   function [2:0] funct3; input [31:0] I; funct3 = I[14:12]; endfunction
   function [6:0] funct7; input [31:0] I; funct7 = I[31:25]; endfunction      


   // Not testing rs1==0 (resp rs2==0) in readsRs1 (resp readsRs2) has
   // little consequence (one does not want to Load to zero in general,
   // and in this case having 1 bubble is no drama...)
   
   function readsRs1;
      input [31:0] I;
      readsRs1 = !(isJAL(I) || isAUIPC(I) || isLUI(I));
   endfunction

   function readsRs2;
      input [31:0] I;
      readsRs2 = isALUreg(I) || isBranch(I) || isStore(I);
   endfunction
   
/******************************************************************************/
   
   reg [63:0] cycle;   
   reg [63:0] instret;

   always @(posedge clk) begin
      cycle <= !resetn ? 0 : cycle + 1;
   end

   wire D_flush;
   wire E_flush;
   
   wire F_stall;
   wire D_stall;

   wire halt; // Halt execution (on ebreak)
   
/******************************************************************************/

   localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;
   
                      /***  F: Instruction fetch ***/   

   reg  [31:0] 	  F_PC;

   /** These two signals come from the Execute stage **/
   wire [31:0] 	  jumpOrBranchAddress;
   wire 	  jumpOrBranch;

   reg [31:0] PROGROM[0:16383]; // 16384 4-bytes words  
                                // 64 Kb of program ROM 
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

   always @(posedge clk) begin

      if(!F_stall) begin
	 FD_instr <= PROGROM[F_PC[15:2]]; 
	 FD_PC    <= F_PC;
	 F_PC     <= F_PC+4;
      end

      if(jumpOrBranch) begin
	 F_PC     <= jumpOrBranchAddress;
      end

      FD_nop <= D_flush | !resetn;
      
      if(!resetn) begin
	 F_PC <= 0;
      end
      
   end
   
/******************************************************************************/
   reg [31:0] FD_PC;   
   reg [31:0] FD_instr;
   reg        FD_nop; 
/******************************************************************************/

                     /*** D: Instruction decode ***/

   /** These three signals come from the Writeback stage **/
   wire        wbEnable;
   wire [31:0] wbData;
   wire [4:0]  wbRdId;

   reg [31:0] RegisterBank [0:31];
   always @(posedge clk) begin

      if(!D_stall) begin
	 DE_PC    <= FD_PC;
	 DE_instr <= (E_flush | FD_nop) ? NOP : FD_instr;
	 
	 DE_Uimm <= {    FD_instr[31],   FD_instr[30:12], {12{1'b0}}};
	 DE_Iimm <= {{21{FD_instr[31]}}, FD_instr[30:20]};
	 DE_Simm <= {{21{FD_instr[31]}}, FD_instr[30:25],FD_instr[11:7]};
	 DE_Bimm <= {{20{FD_instr[31]}}, 
                     FD_instr[7],FD_instr[30:25],FD_instr[11:8],1'b0};
	 DE_Jimm <= {{12{FD_instr[31]}}, 
                     FD_instr[19:12],FD_instr[20],FD_instr[30:21],1'b0};

	 DE_isALUreg <= (FD_instr[6:2]==5'b01100); 
	 DE_isALUimm <= (FD_instr[6:2]==5'b00100); 
	 DE_isBranch <= (FD_instr[6:2]==5'b11000); 
	 DE_isJALR   <= (FD_instr[6:2]==5'b11001); 
	 DE_isJAL    <= (FD_instr[6:2]==5'b11011); 
	 DE_isAUIPC  <= (FD_instr[6:2]==5'b00101); 
	 DE_isLUI    <= (FD_instr[6:2]==5'b01101); 
	 DE_isLoad   <= (FD_instr[6:2]==5'b00000); 
	 DE_isStore  <= (FD_instr[6:2]==5'b01000); 
	 DE_isCSRRS  <= (FD_instr[6:2]==5'b11100) && (FD_instr[14:12]==3'b010);
	 DE_isEBREAK <= (FD_instr[6:2]==5'b11100) && (FD_instr[14:12]==3'b000);	 

	 // wbEnable = !isBranch & !isStore & rdId != 0
	 DE_wbEnable <= (FD_instr[5:2] != 4'b1000) && (FD_instr[11:7] != 5'b00000); 
      end
      
      if(E_flush | FD_nop) begin
	 DE_instr <= NOP;
	 DE_isALUreg <= 1'b0;
	 DE_isALUimm <= 1'b0;
	 DE_isBranch <= 1'b0;
	 DE_isJALR   <= 1'b0;
	 DE_isJAL    <= 1'b0;
	 DE_isAUIPC  <= 1'b0;
	 DE_isLUI    <= 1'b0;
	 DE_isLoad   <= 1'b0;
	 DE_isStore  <= 1'b0;
	 DE_isCSRRS  <= 1'b0;
	 DE_isEBREAK <= 1'b0;

	 DE_wbEnable  <= 1'b0;
      end

      // W to D register forwarding (read and write RF in same cycle)
      if(wbEnable && rdId(MW_instr) == rs1Id(FD_instr)) begin
	 DE_rs1 <= wbData;
      end else begin
	 DE_rs1 <= RegisterBank[rs1Id(FD_instr)];
      end

      // W to D register forwarding (read and write RF in same cycle)     
      if(wbEnable && rdId(MW_instr) == rs2Id(FD_instr)) begin
	 DE_rs2 <= wbData;
      end else begin
	 DE_rs2 <= RegisterBank[rs2Id(FD_instr)];
      end

      if(wbEnable) begin
	 RegisterBank[wbRdId] <= wbData;
      end
   end
   
/******************************************************************************/
   reg [31:0] DE_PC;
   reg [31:0] DE_instr;
   reg [31:0] DE_rs1;
   reg [31:0] DE_rs2;
   
   reg [31:0] DE_Iimm;
   reg [31:0] DE_Bimm;
   reg [31:0] DE_Jimm;
   reg [31:0] DE_Uimm;
   reg [31:0] DE_Simm;

   reg DE_isALUreg;
   reg DE_isALUimm;
   reg DE_isBranch;
   reg DE_isJALR;
   reg DE_isJAL;
   reg DE_isAUIPC;
   reg DE_isLUI;
   reg DE_isLoad;
   reg DE_isStore;
   reg DE_isCSRRS;
   reg DE_isEBREAK;

   reg DE_wbEnable; // !isBranch && !isStore && rdId != 0
   
/******************************************************************************/

                     /*** E: Execute ***/

   /*********** Registrer forwarding ************************************/

   wire E_M_fwd_rs1 = EM_wbEnable && (rdId(EM_instr) == rs1Id(DE_instr));
   wire E_W_fwd_rs1 = !E_M_fwd_rs1 && 
	              MW_wbEnable && (rdId(MW_instr) == rs1Id(DE_instr));

   wire E_M_fwd_rs2 = EM_wbEnable && (rdId(EM_instr) == rs2Id(DE_instr));
   wire E_W_fwd_rs2 = !E_M_fwd_rs2 && 
	              MW_wbEnable && (rdId(MW_instr) == rs2Id(DE_instr));
   
   wire [31:0] E_rs1 = E_M_fwd_rs1 ? EM_Eresult :
	               E_W_fwd_rs1 ? wbData     :
	               DE_rs1;
	       
   wire [31:0] E_rs2 = E_M_fwd_rs2 ? EM_Eresult :
	               E_W_fwd_rs2 ? wbData     :
	               DE_rs2;

   /*********** the ALU *************************************************/

   wire [31:0] E_aluIn1 = E_rs1;
   wire [31:0] E_aluIn2 = (DE_isALUreg | DE_isBranch) ? E_rs2 : DE_Iimm;
   wire [4:0]  E_shamt  = DE_isALUreg ? E_rs2[4:0] : shamt(DE_instr); 

   wire E_minus = DE_instr[30] & DE_isALUreg;
   wire E_arith_shift = DE_instr[30];
   
   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] E_aluPlus = E_aluIn1 + E_aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] E_aluMinus = {1'b1, ~E_aluIn2} + {1'b0,E_aluIn1} + 33'b1;
   wire        E_LT  = 
                 (E_aluIn1[31] ^ E_aluIn2[31]) ? E_aluIn1[31] : E_aluMinus[32];
   wire        E_LTU = E_aluMinus[32];
   wire        E_EQ  = (E_aluMinus[31:0] == 0);

   // Flip a 32 bit word. Used by the shifter (a single shifter for
   // left and right shifts, saves silicium !)
   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

   wire [31:0] E_shifter_in = 
                      (funct3(DE_instr)==3'b001) ? flip32(E_aluIn1) : E_aluIn1;
   
   /* verilator lint_off WIDTH */
   wire [31:0] E_shifter = 
       $signed({E_arith_shift & E_aluIn1[31], E_shifter_in}) >>> E_aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] E_leftshift = flip32(E_shifter);

   reg [31:0] E_aluOut;
   always @(*) begin
      case(funct3(DE_instr))
	3'b000: E_aluOut = E_minus ? E_aluMinus[31:0] : E_aluPlus;
	3'b001: E_aluOut = E_leftshift;
	3'b010: E_aluOut = {31'b0, E_LT};
	3'b011: E_aluOut = {31'b0, E_LTU};
	3'b100: E_aluOut = E_aluIn1 ^ E_aluIn2;
	3'b101: E_aluOut = E_shifter;
	3'b110: E_aluOut = E_aluIn1 | E_aluIn2;
	3'b111: E_aluOut = E_aluIn1 & E_aluIn2;
      endcase
   end
   
   /*********** Branch, JAL, JALR ***********************************/

   reg E_takeBranch;
   always @(*) begin
      case (funct3(DE_instr))
	3'b000: E_takeBranch = E_EQ;
	3'b001: E_takeBranch = !E_EQ;
	3'b100: E_takeBranch = E_LT;
	3'b101: E_takeBranch = !E_LT;
	3'b110: E_takeBranch = E_LTU;
	3'b111: E_takeBranch = !E_LTU;
	default: E_takeBranch = 1'b0;
      endcase 
   end
   
   wire E_JumpOrBranch = 
	DE_isJAL  || DE_isJALR ||  (DE_isBranch && E_takeBranch);

   wire [31:0] E_JumpOrBranchAddr =
	DE_isBranch ? DE_PC + DE_Bimm :
	DE_isJAL    ? DE_PC + DE_Jimm :
	/* JALR */    {E_aluPlus[31:1],1'b0} ;

   wire [31:0] E_result = 
	(DE_isJAL | DE_isJALR) ? DE_PC+4         :
	DE_isLUI               ? DE_Uimm         :
	DE_isAUIPC             ? DE_PC + DE_Uimm : 
        E_aluOut                                 ;
	
   /**************************************************************/
   
   always @(posedge clk) begin
      EM_PC      <= DE_PC;
      EM_instr   <= DE_instr;
      EM_rs2     <= E_rs2;
      EM_Eresult <= E_result;
      EM_addr    <= DE_isStore ? E_rs1 + DE_Simm : 
                                 E_rs1 + DE_Iimm ;
      EM_isLoad   <= DE_isLoad;
      EM_isStore  <= DE_isStore;
      EM_isCSRRS  <= DE_isCSRRS;
      EM_wbEnable <= DE_wbEnable;
   end

   assign halt = resetn & DE_isEBREAK;
   
/******************************************************************************/
   reg [31:0] EM_PC;
   reg [31:0] EM_instr;
   reg [31:0] EM_rs2;
   reg [31:0] EM_Eresult;
   reg [31:0] EM_addr;
   reg        EM_isStore;
   reg        EM_isLoad;
   reg        EM_isCSRRS;
   reg 	      EM_wbEnable;
/******************************************************************************/

                     /*** M: Memory ***/

   wire [2:0] M_funct3 = funct3(EM_instr);
   wire M_isB = (M_funct3[1:0] == 2'b00);
   wire M_isH = (M_funct3[1:0] == 2'b01);

   /*************** STORE **************************/

   wire [31:0] M_STORE_data;
   assign M_STORE_data[ 7: 0] = EM_rs2[7:0];
   assign M_STORE_data[15: 8] = EM_addr[0] ? EM_rs2[7:0]  : EM_rs2[15: 8] ;
   assign M_STORE_data[23:16] = EM_addr[1] ? EM_rs2[7:0]  : EM_rs2[23:16] ;
   assign M_STORE_data[31:24] = EM_addr[0] ? EM_rs2[7:0]  :
			        EM_addr[1] ? EM_rs2[15:8] : EM_rs2[31:24] ;

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on EM_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on EM_addr[1:0])

   wire [3:0] M_STORE_wmask = M_isB ?
	                     (EM_addr[1] ?
		                (EM_addr[0] ? 4'b1000 : 4'b0100) :
		                (EM_addr[0] ? 4'b0010 : 4'b0001)
                             ) :
	                     M_isH ? (EM_addr[1] ? 4'b1100 : 4'b0011) :
                                      4'b1111 ;


   wire  M_isIO         = EM_addr[22];
   wire  M_isRAM        = !M_isIO;

   assign IO_mem_addr  = EM_addr;
   assign IO_mem_wr    = EM_isStore && M_isIO; // && M_STORE_wmask[0];
   assign IO_mem_wdata = EM_rs2;

   wire [3:0] M_wmask = {4{EM_isStore & M_isRAM}} & M_STORE_wmask;
   
   reg [31:0] DATARAM [0:16383]; // 16384 4-bytes words 
                                 // 64 Kb of data RAM in total
   wire [13:0] M_word_addr = EM_addr[15:2];
   
   always @(posedge clk) begin
      MW_Mdata <= DATARAM[M_word_addr];
      if(M_wmask[0]) DATARAM[M_word_addr][ 7:0 ] <= M_STORE_data[ 7:0 ];
      if(M_wmask[1]) DATARAM[M_word_addr][15:8 ] <= M_STORE_data[15:8 ];
      if(M_wmask[2]) DATARAM[M_word_addr][23:16] <= M_STORE_data[23:16];
      if(M_wmask[3]) DATARAM[M_word_addr][31:24] <= M_STORE_data[31:24]; 
   end
   
   initial begin
      $readmemh("DATARAM.hex",DATARAM);
   end
   
   always @(posedge clk) begin
      MW_PC        <= EM_PC;
      MW_instr     <= EM_instr;
      MW_Eresult   <= EM_Eresult;
      MW_IOresult  <= IO_mem_rdata;
      MW_addr      <= EM_addr;
      MW_wbEnable  <= EM_wbEnable;
      MW_isLoad    <= EM_isLoad;
      MW_isCSRRS   <= EM_isCSRRS;
      case(csrId(EM_instr)) 
	2'b00: MW_CSRresult = cycle[31:0];
	2'b10: MW_CSRresult = cycle[63:32];
	2'b01: MW_CSRresult = instret[31:0];
	2'b11: MW_CSRresult = instret[63:32];	 
      endcase 
      if(!resetn) begin
	 instret <= 0;
      end else if(MW_instr != NOP) begin
	 instret <= instret + 1;
      end
   end

/******************************************************************************/
   reg [31:0] MW_PC; 
   reg [31:0] MW_instr; 
   reg [31:0] MW_Eresult;
   reg [31:0] MW_addr;
   reg [31:0] MW_Mdata;
   reg [31:0] MW_IOresult;
   reg [31:0] MW_CSRresult;
   reg        MW_isLoad;
   reg        MW_isCSRRS;
   reg 	      MW_wbEnable;
/******************************************************************************/

                     /*** W: WriteBack ***/
		     
   wire [2:0] W_funct3 = funct3(MW_instr);
   wire W_isB = (W_funct3[1:0] == 2'b00);
   wire W_isH = (W_funct3[1:0] == 2'b01);
   wire W_sext = !W_funct3[2];		     
   wire W_isIO = MW_addr[22];

   /*************** LOAD ****************************/
   
   wire [15:0] W_LOAD_H=MW_addr[1] ? MW_Mdata[31:16]: MW_Mdata[15:0];
   wire  [7:0] W_LOAD_B=MW_addr[0] ? W_LOAD_H[15:8] : W_LOAD_H[7:0];
   wire        W_LOAD_sign=W_sext & (W_isB ? W_LOAD_B[7] : W_LOAD_H[15]);

   wire [31:0] W_Mresult = W_isB ? {{24{W_LOAD_sign}},W_LOAD_B} :
	                   W_isH ? {{16{W_LOAD_sign}},W_LOAD_H} :
                                                      MW_Mdata ;
   
   assign wbData = MW_isLoad  ? (W_isIO ? MW_IOresult : W_Mresult) :
	           MW_isCSRRS ? MW_CSRresult :
	           MW_Eresult;

   assign wbEnable = MW_wbEnable;
   assign wbRdId = rdId(MW_instr);
   
/******************************************************************************/
   assign jumpOrBranchAddress = E_JumpOrBranchAddr;
   assign jumpOrBranch        = E_JumpOrBranch;

   
   wire rs1Hazard = !FD_nop && readsRs1(FD_instr) && 
	            (DE_isLoad || DE_isCSRRS) &&
                    (rs1Id(FD_instr) == rdId(DE_instr)) ;

   wire rs2Hazard = !FD_nop && readsRs2(FD_instr)  &&
 	            (DE_isLoad || DE_isCSRRS) &&	 
                    (rs2Id(FD_instr) == rdId(DE_instr)) ;
   
   wire dataHazard = rs1Hazard || rs2Hazard; // add bubble only if next instr uses result of latency-2 instr
   //wire dataHazard = !FD_nop && (DE_isLoad || DE_isCSRRS); // always add bubble after latency-2 instr
   
   
   assign F_stall = dataHazard | halt;
   assign D_stall = dataHazard | halt;
   
   assign D_flush = E_JumpOrBranch;
   assign E_flush = E_JumpOrBranch | dataHazard;

/******************************************************************************/

`ifdef BENCH
   always @(posedge clk) begin
      if(halt) $finish();
   end
`endif


   always @(posedge clk) begin
      if(1'b0 & resetn) begin
	 $write("[W] PC=%h ", MW_PC);
	 $write("     ");
	 riscv_disasm(MW_instr,MW_PC);
	 if(wbEnable) $write("    x%0d <- 0x%0h",rdId(MW_instr),wbData);
	 $write("\n");

	 $write("[M] PC=%h ", EM_PC);
	 $write("     ");	 
	 riscv_disasm(EM_instr,EM_PC);
	 $write("\n");

	 $write("[E] PC=%h ", DE_PC);
	 $write("[%s%s] ",
		E_M_fwd_rs1 ? "M": E_W_fwd_rs1 ? "W" : " ",
		E_M_fwd_rs2 ? "M": E_W_fwd_rs2 ? "W" : " "
	 );	 
	 riscv_disasm(DE_instr,DE_PC);
	 if(DE_instr != NOP) begin
	    $write("  rs1=0x%h  rs2=0x%h  ",E_rs1, E_rs2);
	 end
	 $write("\n");

	 $write("[D] PC=%h ", FD_PC);
	 $write("[%s%s] ",
		rs1Hazard ? "*" : " ",
		rs2Hazard ? "*" : " "
	 );	 
	 riscv_disasm(FD_nop ? NOP : FD_instr,FD_PC);
	 $write("\n");

	 $write("[F] PC=%h ", F_PC); 
	 if(jumpOrBranch) $write(" PC <- 0x%0h",jumpOrBranchAddress);
	 $write("\n");
	 
	 $display("");
      end
   end


/******************************************************************************/
   
endmodule


module SOC (
    input 	     CLK, // system clock 
    input 	     RESET,// reset button
    output reg [4:0] LEDS, // system LEDs
    input 	     RXD, // UART receive
    output 	     TXD  // UART transmit
);

   wire clk;
   wire resetn;
   
   wire [31:0] IO_mem_addr;
   wire [31:0] IO_mem_rdata;
   wire [31:0] IO_mem_wdata;
   wire        IO_mem_wr;

   Processor CPU(
      .clk(clk),
      .resetn(resetn),
      .IO_mem_addr(IO_mem_addr),
      .IO_mem_rdata(IO_mem_rdata),
      .IO_mem_wdata(IO_mem_wdata),
      .IO_mem_wr(IO_mem_wr)
   );

   wire [13:0] IO_wordaddr = IO_mem_addr[15:2];
   
   // Memory-mapped IO in IO page, 1-hot addressing in word address.   
   localparam IO_LEDS_bit      = 0;  // W five leds
   localparam IO_UART_DAT_bit  = 1;  // W data to send (8 bits) 
   localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: busy sending
   
   always @(posedge clk) begin
      if(IO_mem_wr & IO_wordaddr[IO_LEDS_bit]) begin
	 LEDS <= IO_mem_wdata[4:0];
      end
   end

   wire uart_valid = IO_mem_wr & IO_wordaddr[IO_UART_DAT_bit];
   wire uart_ready;

   corescore_emitter_uart #(
      .clk_freq_hz(`CPU_FREQ*1000000),
        .baud_rate(1000000)
   ) UART(
      .i_clk(clk),
      .i_rst(!resetn),
      .i_data(IO_mem_wdata[7:0]),
      .i_valid(uart_valid),
      .o_ready(uart_ready),
      .o_uart_tx(TXD)      			       
   );
   
   assign IO_mem_rdata = 
		    IO_wordaddr[IO_UART_CNTL_bit] ? { 22'b0, !uart_ready, 9'b0}
	                                          : 32'b0;

`ifdef BENCH
   always @(posedge clk) begin
      if(uart_valid) begin
//	 $display("UART: %c", IO_mem_wdata[7:0]);
	 $write("%c", IO_mem_wdata[7:0] );
	 $fflush(32'h8000_0001);
      end
   end
`endif   
   
   // Gearbox and reset circuitry.
   Clockworks CW(
     .CLK(CLK),
     .RESET(RESET),
     .clk(clk),
     .resetn(resetn)
   );

endmodule

 
