/*
 * pipeline6.v
 * Let us see how to morph our multi-cycle CPU into a pipelined CPU !
 * Step 8: dynamic branch prediction: gshare
 */
 
`default_nettype none
`include "clockworks.v"
`include "emitter_uart.v"

//`define VERBOSE

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
   ALUreg  // rd <- rs1 OP rs2   
   ALUimm  // rd <- rs1 OP Iimm
   Branch  // if(rs1 OP rs2) PC<-PC+Bimm
   JALR    // rd <- PC+4; PC<-rs1+Iimm
   JAL     // rd <- PC+4; PC<-PC+Jimm
   AUIPC   // rd <- PC + Uimm
   LUI     // rd <- Uimm   
   Load    // rd <- mem[rs1+Iimm]
   Store   // mem[rs1+Simm] <- rs2
   SYSTEM  // special
 */

/******************************************************************************/

   /* Instruction decoder as functions (we will use them several times) */

   /* The 10 "recognizers" for the 10 codeops */
   function isALUreg; input [31:0] I; isALUreg=(I[6:0]==7'b0110011); endfunction
   function isALUimm; input [31:0] I; isALUimm=(I[6:0]==7'b0010011); endfunction
   function isBranch; input [31:0] I; isBranch=(I[6:0]==7'b1100011); endfunction
   function isJALR;   input [31:0] I; isJALR  =(I[6:0]==7'b1100111); endfunction
   function isJAL;    input [31:0] I; isJAL   =(I[6:0]==7'b1101111); endfunction
   function isAUIPC;  input [31:0] I; isAUIPC =(I[6:0]==7'b0010111); endfunction
   function isLUI;    input [31:0] I; isLUI   =(I[6:0]==7'b0110111); endfunction
   function isLoad;   input [31:0] I; isLoad  =(I[6:0]==7'b0000011); endfunction
   function isStore;  input [31:0] I; isStore =(I[6:0]==7'b0100011); endfunction
   function isSYSTEM; input [31:0] I; isSYSTEM=(I[6:0]==7'b1110011); endfunction

   /* Register indices */
   function [4:0] rs1Id; input [31:0] I; rs1Id = I[19:15];      endfunction
   function [4:0] rs2Id; input [31:0] I; rs2Id = I[24:20];      endfunction
   function [4:0] shamt; input [31:0] I; shamt = I[24:20];      endfunction   
   function [4:0] rdId;  input [31:0] I; rdId  = I[11:7];       endfunction
   function [1:0] csrId; input [31:0] I; csrId = {I[27],I[21]}; endfunction

   /* funct3 and funct7 */
   function [2:0] funct3; input [31:0] I; funct3 = I[14:12]; endfunction
   function [6:0] funct7; input [31:0] I; funct7 = I[31:25]; endfunction      

   
   /* EBREAK and CSRRS instruction "recognizers" */
   function isEBREAK; 
      input [31:0] I; 
      isEBREAK = (isSYSTEM(I) && funct3(I) == 3'b000); 
   endfunction

   function isCSRRS; 
      input [31:0] I; 
      isCSRRS = (isSYSTEM(I) && funct3(I) == 3'b010); 
   endfunction
   
   /* The 5 immediate formats */
   function [31:0] Uimm; 
      input [31:0] I; 
      Uimm={I[31:12],{12{1'b0}}}; 
   endfunction
   
   function [31:0] Iimm; 
      input [31:0] I; 
      Iimm={{21{I[31]}},I[30:20]};
   endfunction
   
   function [31:0] Simm; 
      input [31:0] I; 
      Simm={{21{I[31]}},I[30:25],I[11:7]};
   endfunction

   function [31:0] Bimm;
      input [31:0] I;
      Bimm = {{20{I[31]}},I[7],I[30:25],I[11:8],1'b0};
   endfunction 

   function [31:0] Jimm;
      input [31:0] I;
      Jimm = {{12{I[31]}},I[19:12],I[20],I[30:21],1'b0};      
   endfunction

   function writesRd;
      input [31:0] I;
      writesRd = !isStore(I) && !isBranch(I);
   endfunction

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

   reg  [31:0] 	  PC;
   
   reg [31:0] PROGROM[0:16383]; // 16384 4-bytes words  
                                // 64 Kb of program ROM 
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

   // Note: E's jumpOrBranch signals are registered in EM (1 cycle later), 
   // hence taken into account in F_PC mux (1 cycle before). Doing so
   // avoids a *huge* critical path (that generates E_JumpOrBranch, that
   // uses the ALU branch result E_takeBranch, and hence that comprises 
   // register forwarding  & ALU)
   
   wire [31:0] F_PC = 
	       D_JumpOrBranchNow  ? D_JumpOrBranchAddr  :
	       EM_JumpOrBranchNow ? EM_JumpOrBranchAddr :
	                            PC;
   
   always @(posedge clk) begin
      
      if(!F_stall) begin
	 FD_instr <= PROGROM[F_PC[15:2]]; 
	 FD_PC    <= F_PC;
	 PC       <= F_PC+4;
      end
      

      // Cannot write NOP to FD_instr, because
      // whenever a BRAM read is involved, do
      // nothing else than sending the result
      // to a reg.
      FD_nop <= D_flush | !resetn;
      
      if(!resetn) begin
	 PC <= 0;
      end
   end
   
/******************************************************************************/
   reg [31:0] FD_PC;   
   reg [31:0] FD_instr;
   reg 	      FD_nop;
/******************************************************************************/

                     /*** D: Instruction decode ***/

   // Branch prediction

   // 83% success with HISTO_BITS=8, ADDR_BITS=12
   // 80% success with HISTO_BITS=5, ADDR_BITS=10   
   // 78% success with HISTO_BITS=4, ADDR_BITS=8   
   localparam BP_HISTO_BITS=5;
   localparam BP_ADDR_BITS=10;
   localparam BP_SIZE=1<<BP_ADDR_BITS;
   
   reg [BP_HISTO_BITS-1:0] BHT[BP_SIZE-1:0]; // Branch History Table
   reg [1:0]               BPT[BP_SIZE-1:0]; // Branch Prediction Table

   function [BP_ADDR_BITS-1:0] BHT_index;
      input [31:0] PC;
      BHT_index = PC[BP_ADDR_BITS+1:2];
   endfunction 
   
   function [BP_ADDR_BITS-1:0] BPT_index;
      input [31:0] PC;

      // Choose indexing for dynamic branch prediction
      // (uncomment one of the following choices)      
      // Used if D_predictBranch is set to dynamic (later in this file)
      
      // 1: simple 2-bits counter without history      
      // BPT_index = BHT_index(PC); 

      // 2: gselect      
      // /* verilator lint_off WIDTH */
      // BPT_index = {BHT_index(PC), BHT[BHT_index(PC)]}; 
      // /* verilator lint_on WIDTH */      

      // 3: gshare
      BPT_index = BHT_index(PC) ^  
                  {BHT[BHT_index(PC)],{BP_ADDR_BITS-BP_HISTO_BITS{1'b0}}}; 
   endfunction

   // Choose branch prediction strategy
   // (uncomment one of the following choices)   
   //wire D_predictBranch = 1'd0;                   // 1. predict not taken
   //wire D_predictBranch = 1'd1;                   // 2. predict taken
   //wire D_predictBranch = FD_instr[31];           // 3. BTFNT 
   wire D_predictBranch = BPT[BPT_index(FD_PC)][1]; // 4. dynamic

   
   // Next fetch gets address from JAL target or from Branch target
   // if branch is predicted.
   
   wire D_JumpOrBranchNow = !FD_nop && (
             isJAL(FD_instr) || 
             (isBranch(FD_instr) && D_predictBranch)
        );
   
   wire [31:0] D_JumpOrBranchAddr =  
               FD_PC + (isJAL(FD_instr) ? Jimm(FD_instr) : Bimm(FD_instr)); 
   
   /** These three signals come from the Writeback stage **/
   wire        wbEnable;
   wire [31:0] wbData;
   wire [4:0]  wbRdId;

   reg [31:0] RegisterBank [0:31];
   always @(posedge clk) begin

      if(!D_stall) begin
	 DE_PC    <= FD_PC;
	 DE_instr <= (E_flush | FD_nop) ? NOP : FD_instr;
	 DE_predictBranch <= D_predictBranch;
	 DE_BHTindex <= BHT_index(FD_PC);
	 DE_BPTindex <= BPT_index(FD_PC);
      end
      
      if(E_flush) begin
	 DE_instr <= NOP;
      end
      
      if(wbEnable) begin
	 RegisterBank[wbRdId] <= wbData;
      end
   end

/******************************************************************************/
   reg [31:0] DE_PC;
   reg [31:0] DE_instr;
   wire [31:0] DE_rs1 = RegisterBank[rs1Id(DE_instr)];
   wire [31:0] DE_rs2 = RegisterBank[rs2Id(DE_instr)];
   reg 	       DE_predictBranch;
   reg [BP_ADDR_BITS-1:0] DE_BHTindex;
   reg [BP_ADDR_BITS-1:0] DE_BPTindex;
/******************************************************************************/

                     /*** E: Execute ***/

   /*********** Registrer forwarding ************************************/

   wire E_M_fwd_rs1 = rdId(EM_instr) != 0 && writesRd(EM_instr) && 
	              (rdId(EM_instr) == rs1Id(DE_instr));
   
   wire E_W_fwd_rs1 = rdId(MW_instr) != 0 && writesRd(MW_instr) && 
	              (rdId(MW_instr) == rs1Id(DE_instr));

   wire E_M_fwd_rs2 = rdId(EM_instr) != 0 && writesRd(EM_instr) && 
	              (rdId(EM_instr) == rs2Id(DE_instr));
   
   wire E_W_fwd_rs2 = rdId(MW_instr) != 0 && writesRd(MW_instr) && 
	              (rdId(MW_instr) == rs2Id(DE_instr));
   
   wire [31:0] E_rs1 = E_M_fwd_rs1 ? EM_Eresult :
	               E_W_fwd_rs1 ? wbData     :
	               DE_rs1;
	       
   wire [31:0] E_rs2 = E_M_fwd_rs2 ? EM_Eresult :
	               E_W_fwd_rs2 ? wbData     :
	               DE_rs2;

   /*********** the ALU *************************************************/

   wire [31:0] E_aluIn1 = E_rs1;
   
   wire [31:0] E_aluIn2 = 
         (isALUreg(DE_instr) | isBranch(DE_instr)) ? E_rs2 : Iimm(DE_instr);
   
   wire [4:0]  E_shamt  = isALUreg(DE_instr) ? E_rs2[4:0] : shamt(DE_instr); 

   wire E_minus = DE_instr[30] & isALUreg(DE_instr);
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

   // Jump if mispredicted branch or JALR

`ifdef BENCH
   integer nbBranch = 0;
   integer nbPredictHit = 0;
   integer nbJAL  = 0;
   integer nbJALR = 0;   
`endif   

   function [1:0] incdec_sat;
      input [1:0] prev;
      input dir;
//    incdec_sat = dir ? 2'b11 : 2'b00; // simple binary instead of bimodal
      incdec_sat = 
 	   {dir, prev} == 3'b000 ? 2'b00 :
	   {dir, prev} == 3'b000 ? 2'b00 :
           {dir, prev} == 3'b001 ? 2'b00 :
	   {dir, prev} == 3'b010 ? 2'b01 :
	   {dir, prev} == 3'b011 ? 2'b10 :		
	   {dir, prev} == 3'b100 ? 2'b01 :
	   {dir, prev} == 3'b101 ? 2'b10 :
	   {dir, prev} == 3'b110 ? 2'b11 :
	                           2'b11 ;
   endfunction;


   wire E_JumpOrBranch = (
         isJALR(DE_instr) || 
         (isBranch(DE_instr) && (E_takeBranch^DE_predictBranch))
   );

   wire [31:0] E_JumpOrBranchAddr =
	isBranch(DE_instr) ? 
                     (DE_PC + (DE_predictBranch ? 4 : Bimm(DE_instr))) :
	/* JALR */   {E_aluPlus[31:1],1'b0} ;

   wire [31:0] E_result = 
	(isJAL(DE_instr) | isJALR(DE_instr)) ? DE_PC+4                :
	isLUI(DE_instr)                      ? Uimm(DE_instr)         :
	isAUIPC(DE_instr)                    ? DE_PC + Uimm(DE_instr) : 
        E_aluOut                                                      ;

   /**************************************************************/
   
   always @(posedge clk) begin
      EM_PC      <= DE_PC;
      EM_instr   <= DE_instr;
      EM_rs2     <= E_rs2;
      EM_Eresult <= E_result;
      EM_addr    <= isStore(DE_instr) ? E_rs1 + Simm(DE_instr) : 
                                        E_rs1 + Iimm(DE_instr) ;
      
      EM_JumpOrBranchNow  <= E_JumpOrBranch;
      EM_JumpOrBranchAddr <= E_JumpOrBranchAddr;
      
      if(isBranch(DE_instr)) begin
	 BHT[DE_BHTindex] <= { BHT[DE_BHTindex][BP_HISTO_BITS-2:0], 
                               E_takeBranch                           };
	 BPT[DE_BPTindex] <= incdec_sat(BPT[DE_BPTindex], E_takeBranch);
      end
   end

`ifdef BENCH
   always @(posedge clk) begin
      if(resetn) begin
	 if(isBranch(DE_instr)) begin
	    nbBranch <= nbBranch + 1;
	    if(E_takeBranch == DE_predictBranch) begin
	       nbPredictHit <= nbPredictHit + 1;
	    end
	 end
	 if(isJAL(DE_instr)) begin
	    nbJAL <= nbJAL + 1;
	 end
	 if(isJALR(DE_instr)) begin
	    nbJALR <= nbJALR + 1;
	 end
      end
   end
`endif	 

   
   assign halt = resetn & isEBREAK(DE_instr);
   
/******************************************************************************/
   reg [31:0] EM_PC;
   reg [31:0] EM_instr;
   reg [31:0] EM_rs2;
   reg [31:0] EM_Eresult;
   reg [31:0] EM_addr;
   reg        EM_JumpOrBranchNow;
   reg [31:0] EM_JumpOrBranchAddr;
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
   assign IO_mem_wr    = isStore(EM_instr) && M_isIO; // && M_STORE_wmask[0];
   assign IO_mem_wdata = EM_rs2;

   wire [3:0] M_wmask = {4{isStore(EM_instr) & M_isRAM}} & M_STORE_wmask;
   
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
   
   assign wbData = 
	       isLoad(MW_instr)  ? (W_isIO ? MW_IOresult : W_Mresult) :
	       isCSRRS(MW_instr) ? MW_CSRresult :
	       MW_Eresult;

   assign wbEnable = writesRd(MW_instr) && rdId(MW_instr) != 0;
   assign wbRdId = rdId(MW_instr);
   
/******************************************************************************/

   // Not testing that rdId(DE_instr) != 0 because in general one
   // does not Load to zero ! (idem for CSRRS).
   wire rs1Hazard = readsRs1(FD_instr) && (rs1Id(FD_instr) == rdId(DE_instr)) ;
   wire rs2Hazard = readsRs2(FD_instr) && (rs2Id(FD_instr) == rdId(DE_instr)) ;
   
   wire dataHazard = !FD_nop  &&  
                     (isLoad(DE_instr)||isCSRRS(DE_instr)) && 
                     (rs1Hazard || rs2Hazard);
   
   assign F_stall = dataHazard | halt;
   assign D_stall = dataHazard | halt;
   
   assign D_flush = E_JumpOrBranch;
   assign E_flush = E_JumpOrBranch | dataHazard;

/******************************************************************************/

`ifdef BENCH
   /* verilator lint_off WIDTH */
   always @(posedge clk) begin
      if(halt) begin
	 $display("Simulated processor's report");
	 $display("----------------------------");
	 $display("Pred hits  = %3.3f\%%",
		   nbPredictHit*100.0/nbBranch	 );
	 $display("CPI        = %3.3f",(cycle*1.0)/(instret*1.0));
	 $display("Instr. mix = (Branch:%3.3f\%% JAL:%3.3f\%% JALR:%3.3f\%%)",
		  nbBranch*100.0/instret,
		     nbJAL*100.0/instret, 
		    nbJALR*100.0/instret);
	 $finish();
      end
   end
   /* verilator lint_on WIDTH */
`endif

`ifdef VERBOSE
   always @(posedge clk) begin
      if(resetn & !halt) begin
	 $write("D_JoB=%d E_JoB=%d  D_flush=%d E_flush=%d\n", 
		D_JumpOrBranchNow, EM_JumpOrBranchNow, D_flush, E_flush
	 );
	 
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
	 $write("     ");	 
	 riscv_disasm(DE_instr,DE_PC);
	 if(DE_instr != NOP) begin
	    $write("  rs1=0x%h  rs2=0x%h  ",DE_rs1, DE_rs2);
	    if(isBranch(DE_instr)) begin
	       $write(" taken:%0d  prediction OK:%0d",
		      E_takeBranch, 
		      (E_takeBranch == DE_predictBranch) ? 1 : 0
               );
	    end
	 end
	 $write("\n");

	 $write("[D] PC=%h ", FD_PC);
	 $write("[%s%s] ",
		dataHazard && rs1Hazard?"*":" ", 
		dataHazard && rs2Hazard?"*":" ");	 
	 riscv_disasm(FD_nop ? NOP : FD_instr,FD_PC);
	 if(isBranch(FD_instr)) begin
	    $write(" predict taken:%0d",D_predictBranch); 
	 end
	 $write("\n");

	 $write("[F] PC=%h ", F_PC);
	 if(D_JumpOrBranchNow) $write(" PC <- [D] 0x%0h",D_JumpOrBranchAddr);
	 if(EM_JumpOrBranchNow) $write(" PC <- [E] 0x%0h",EM_JumpOrBranchAddr);
	 $write("\n");
	 
	 $display("");
      end
   end
`endif
   

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
`ifdef VERBOSE	 
	 $display("UART: %c", IO_mem_wdata[7:0]);
`else	 
	 $write("%c", IO_mem_wdata[7:0] );
	 $fflush(32'h8000_0001);
`endif	 
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

 
