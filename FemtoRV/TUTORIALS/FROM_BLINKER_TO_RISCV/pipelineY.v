/**
 * pipelineY_generic.v
 * femtorv32-tordboyau
 * Configurable 5-stages pipelined RV32IM
 * Bruno Levy, Sept 2022
 */

`define CONFIG_PC_PREDICT // enables D -> F path (needed by RAS and GSHARE)
`define CONFIG_RAS        // return address stack
`define CONFIG_GSHARE     // gshare branch prediction (or BTFNT if not set)

//`define CONFIG_RV32M      // RV32M instruction set (MUL,DIV,REM)

//`define CONFIG_DEBUG      // debug mode, displays execution
                            // See "debugger" section in source
                            // to define breakpoints

`define CONFIG_INITIALIZE // initialize register file and BHT table
                            // (required by Icarus/iverilog
                            // and by some synth tools)

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

`ifdef BENCH
`include "riscv_disassembly.v"
`endif

/******************************************************************************/

 /*
   Reminder for the 10 RISC-V codeops
   ----------------------------------
   5'b01100 | ALUreg  | rd <- rs1 OP rs2
   5'b00100 | ALUimm  | rd <- rs1 OP Iimm
   5'b11000 | Branch  | if(rs1 OP rs2) PC<-PC+Bimm
   5'b11001 | JALR    | rd <- PC+4; PC<-rs1+Iimm
   5'b11011 | JAL     | rd <- PC+4; PC<-PC+Jimm
   5'b00101 | AUIPC   | rd <- PC + Uimm
   5'b01101 | LUI     | rd <- Uimm
   5'b00000 | Load    | rd <- mem[rs1+Iimm]
   5'b01000 | Store   | mem[rs1+Simm] <- rs2
   5'b11100 | SYSTEM  | special
 */

/******************************************************************************/

`ifdef CONFIG_INITIALIZE
   // Iteration variable for the "initial" blocks
   integer i;
`endif

   // CSRs (cycle and retired instructions counters)
   reg [63:0] cycle;
   reg [63:0] instret;

   always @(posedge clk) begin
      cycle <= !resetn ? 0 : cycle + 1;
   end

   // Pipeline control
   // Note: E_stall and M_flush are only used if RV32M is configured
   // (multicycle ALU).

   wire F_stall;

   wire D_stall;
   wire D_flush;

   wire E_stall;
   wire E_flush;

   wire M_flush;

   wire halt; // Halt execution (on ebreak)

/******************************************************************************/

                      /***  F: Instruction fetch ***/

   reg  [31:0] PC;

   reg [31:0] PROGROM[0:16383]; // 16384 4-bytes words
                                // 64 Kb of program ROM
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

`ifdef CONFIG_PC_PREDICT
   wire [31:0] F_PC =
	       D_predictPC  ? D_PCprediction  :
	       EM_correctPC ? EM_PCcorrection :
	                      PC;
`else
   wire [31:0] F_PC = EM_correctPC ? EM_PCcorrection :
	              PC;
`endif

   wire [31:0] F_PCplus4 = F_PC + 4;

   always @(posedge clk) begin

      if(!F_stall) begin
	 FD_instr <= PROGROM[F_PC[15:2]];
	 FD_PC    <= F_PC;
	 PC       <= F_PCplus4;
      end

      FD_nop <= D_flush | !resetn;

      if(!resetn) begin
	 PC <= 0;
      end

   end

/******************************************************************************/
/******************************************************************************/
   reg [31:0] FD_PC;
   reg [31:0] FD_instr;
   reg        FD_nop; // Needed because I cannot directly write NOP to FD_instr
                      // because FD_instr is plugged to PROGROM's output port.
/******************************************************************************/
/******************************************************************************/

                     /*** D: Instruction decode ***/

   /** These three signals come from the Writeback stage **/
   wire        wbEnable;
   wire [31:0] wbData;
   wire [4:0]  wbRdId;

   wire [4:0]  D_rdId  = FD_instr[11:7];
   wire [4:0]  D_rs1Id = FD_instr[19:15];
   wire [4:0]  D_rs2Id = FD_instr[24:20];

   // commented-out codeop recognizers are optimized below
// wire D_isJAL    = (FD_instr[6:2]==5'b11011);
// wire D_isJALR   = (FD_instr[6:2]==5'b11001);
// wire D_isAUIPC  = (FD_instr[6:2]==5'b00101);
// wire D_isLUI    = (FD_instr[6:2]==5'b01101);
// wire D_isBranch = (FD_instr[6:2]==5'b11000);
   wire D_isALUreg = (FD_instr[6:2]==5'b01100);
   wire D_isALUimm = (FD_instr[6:2]==5'b00100);
   wire D_isLoad   = (FD_instr[6:2]==5'b00000);
   wire D_isStore  = (FD_instr[6:2]==5'b01000);
   wire D_isSYSTEM = (FD_instr[6:2]==5'b11100);

   // optimized codop recognizers
   wire D_isJAL    = FD_instr[3];
   wire D_isJALR   = {FD_instr[6], FD_instr[3], FD_instr[2]} == 3'b101;
   wire D_isLUI    = FD_instr[6:4] == 3'b111;
   wire D_isAUIPC  = FD_instr[6:4] == 3'b101;
   wire D_isBranch = {FD_instr[6], FD_instr[4], FD_instr[2]} == 3'b100;


   wire D_isJALorJALR  = (FD_instr[2] & FD_instr[6]);
   wire D_isLUIorAUIPC = (FD_instr[4] & FD_instr[6]);


   wire D_readsRs1 = !(D_isJAL || D_isLUIorAUIPC);

   wire D_readsRs2 = (FD_instr[5] && (FD_instr[3:2] == 2'b00));
                  // <=> D_isALUreg || D_isBranch || D_isStore || D_isSYSTEM

   wire [31:0] D_Uimm = { FD_instr[31],FD_instr[30:12], {12{1'b0}}};

   wire [31:0] D_Bimm = {{20{FD_instr[31]}},
                         FD_instr[7],FD_instr[30:25],FD_instr[11:8],1'b0};

   wire [31:0] D_Jimm = {{12{FD_instr[31]}},
                         FD_instr[19:12],FD_instr[20],FD_instr[30:21],1'b0};

`ifdef CONFIG_PC_PREDICT
 `ifdef CONFIG_GSHARE
   localparam BP_HISTO_BITS=9;
   localparam BP_ADDR_BITS=12;

   localparam BHT_INDEX_BITS=BP_ADDR_BITS;
   localparam BHT_SIZE=1<<BHT_INDEX_BITS;

   // global history
   reg [BP_HISTO_BITS-1:0] branch_history;

   // branch history table (2 bits per entry)
   reg [1:0] BHT[BHT_SIZE-1:0];

`ifdef CONFIG_INITIALIZE
   initial begin
      branch_history = 0;
      for(i=0; i<BHT_SIZE; i++) begin
	 BHT[i] = 2'b01; // all entries of BHT initialized as "weakly taken"
      end
   end
`endif

   // gets the index in the branch prediction table
   // from the PC
   function [BHT_INDEX_BITS-1:0] BHT_index;
      input [31:0] PC;
   /* verilator lint_off WIDTH */
      BHT_index = PC[BP_ADDR_BITS+1:2] ^
                  (branch_history << (BP_ADDR_BITS - BP_HISTO_BITS));
   /* verilator lint_on WIDTH */
   endfunction

   wire D_predictBranch = BHT[BHT_index(FD_PC)][1];

 `else
   // No GSHARE branch predictor,
   // use BTFNT (Backwards taken forwards not taken)
   // I[31]=Bimm sgn (pred bkwd branch taken)
   wire D_predictBranch = FD_instr[31];
 `endif

 `ifdef CONFIG_RAS
   // code below is equivalent (in this context) to:
   // wire D_predictPC = !FD_nop && (
   //   D_isJAL || D_isJALR || (D_isBranch && D_predictBranch)
   // );
   // JAL:    11011
   // JALR:   11001
   // Branch: 11000
   // The three start by 110, and it is the only ones
   wire D_predictPC = !FD_nop &&
	 (FD_instr[6:4] == 3'b110) && (FD_instr[2] | D_predictBranch);

   // Return address stack

   reg [31:0] RAS_0;
   reg [31:0] RAS_1;
   reg [31:0] RAS_2;
   reg [31:0] RAS_3;

   wire [31:0] D_PCprediction =
                /* D_isJALR */ FD_instr[3:2] == 2'b01 ? RAS_0 :
	        (FD_PC + (D_isJAL ? D_Jimm : D_Bimm));

 `else // !`ifdef CONFIG_RAS
     wire D_predictPC = !FD_nop && (D_isJAL || (D_isBranch && D_predictBranch));
     wire [31:0] D_PCprediction = (FD_PC + (D_isJAL ? D_Jimm : D_Bimm));
 `endif
`endif // `CONFIG_PC_PREDICT

   reg [31:0] RegisterBank [0:31];

`ifdef CONFIG_INITIALIZE
   initial begin
      for(i=0; i<32; i++) begin
	 RegisterBank[i] = 0;
      end
   end
`endif

   always @(posedge clk) begin


      if(!D_stall) begin

	 DE_rdId  <= D_rdId;
	 DE_rs1Id <= D_rs1Id;
	 DE_rs2Id <= D_rs2Id;

	 DE_funct3    <= FD_instr[14:12];
	 DE_funct3_is <= 8'b00000001 << FD_instr[14:12];
	 DE_funct7    <= FD_instr[30];
	 DE_csrId     <= {FD_instr[27],FD_instr[21]};

`ifdef CONFIG_RV32M
	 DE_isRV32M <= D_isALUreg & FD_instr[25];
	 DE_isMUL   <= D_isALUreg & FD_instr[25] & !FD_instr[14];
	 DE_isDIV   <= D_isALUreg & FD_instr[25] &  FD_instr[14];
`endif

	 DE_nop <= 1'b0;


	 DE_isALUreg <= D_isALUreg;
	 DE_isALUimm <= D_isALUimm;
	 DE_isBranch <= D_isBranch;
	 DE_isJALR   <= D_isJALR;
	 DE_isJAL    <= D_isJAL;
	 DE_isAUIPC  <= D_isAUIPC;
	 DE_isLUI    <= D_isLUI;
	 DE_isLoad   <= D_isLoad;
	 DE_isStore  <= D_isStore;
	 DE_isCSRRS  <= D_isSYSTEM &&  FD_instr[13];
	 DE_isEBREAK <= D_isSYSTEM && !FD_instr[13];

	 // wbEnable = !isBranch & !isStore
	 // Note: EM_wbEnable = DE_wbEnable && (rdId != 0)
	 DE_wbEnable <= (FD_instr[5:2]  != 4'b1000);

	 DE_IorSimm <= {
			{21{FD_instr[31]}},
			D_isStore ? {FD_instr[30:25],FD_instr[11:7]} :
			             FD_instr[30:20]
			};

`ifdef CONFIG_PC_PREDICT
	 // Used in case of misprediction:
	 //    PC+Bimm if predict not taken, PC+4 if predict taken
	 DE_PCplus4orBimm <= FD_PC + (D_predictBranch ? 4 : D_Bimm);
	 DE_predictBranch <= D_predictBranch;
 `ifdef CONFIG_GSHARE
	 DE_BHTindex  <= BHT_index(FD_PC);
 `endif
 `ifdef CONFIG_RAS
	 DE_predictRA <= RAS_0;
	 if(!FD_nop && !D_flush) begin
	    if(D_isJAL && D_rdId==1) begin
	       RAS_3 <= RAS_2;
	       RAS_2 <= RAS_1;
	       RAS_1 <= RAS_0;
	       RAS_0 <= FD_PC + 4;
	    end
	    if(D_isJALR && D_rdId==0 && (D_rs1Id == 1 || D_rs1Id==5)) begin
	       RAS_0 <= RAS_1;
	       RAS_1 <= RAS_2;
	       RAS_2 <= RAS_3;
	    end
	 end
 `endif
`else
	 DE_PCplusBorJimm <= FD_PC + (D_isJAL ? D_Jimm : D_Bimm);
`endif

	 // Code below is equivalent to:
	 // DE_PCplus4orUimm =
	 //    ((isLUI ? 0 : FD_PC)) + ((isJAL | isJALR) ? 4 : Uimm)
	 // (knowing that isLUI | isAUIPC | isJAL | isJALR)
	 DE_PCplus4orUimm <= ({32{FD_instr[6:5]!=2'b01}} & FD_PC) +
                             (D_isJALorJALR ? 4 : D_Uimm);

	 DE_isJALorJALRorLUIorAUIPC <= FD_instr[2];
      end

      if(E_flush | FD_nop) begin
	 DE_nop      <= 1'b1;
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
	 DE_wbEnable <= 1'b0;
`ifdef CONFIG_RV32M
	 DE_isRV32M <= 1'b0;
	 DE_isMUL   <= 1'b0;
	 DE_isDIV   <= 1'b0;

`endif
	 DE_isJALorJALRorLUIorAUIPC <= 1'b0;
      end

      if(wbEnable) begin
	 RegisterBank[wbRdId] <= wbData;
      end

   end

/******************************************************************************/
/******************************************************************************/
   reg        DE_nop; // Needed by instret in W stage
   reg [4:0]  DE_rdId;
   reg [4:0]  DE_rs1Id;
   reg [4:0]  DE_rs2Id;

   reg [1:0]  DE_csrId;
   reg [2:0]  DE_funct3;
   (* onehot *) reg [7:0] DE_funct3_is;
   reg [5:5]  DE_funct7;

   reg [31:0] DE_IorSimm;

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

`ifdef CONFIG_RV32M
   reg DE_isRV32M;
   reg DE_isMUL;
   reg DE_isDIV;
`endif

   reg DE_wbEnable; // !isBranch && !isStore && rdId != 0

   reg DE_isJALorJALRorLUIorAUIPC;

`ifdef CONFIG_PC_PREDICT
   reg [31:0] DE_PCplus4orBimm;
   reg DE_predictBranch;
 `ifdef CONFIG_RAS
   reg [31:0] DE_predictRA;
 `endif
 `ifdef CONFIG_GSHARE
   reg [BHT_INDEX_BITS-1:0] DE_BHTindex;
 `endif
`else
   reg [31:0] DE_PCplusBorJimm;
`endif

   reg [31:0] DE_PCplus4orUimm;

/******************************************************************************/
/******************************************************************************/
                     /*** E: Execute ***/

   /*********** Registrer forwarding ************************************/

   wire E_M_fwd_rs1 = EM_wbEnable && (EM_rdId == DE_rs1Id);
   wire E_W_fwd_rs1 = MW_wbEnable && (MW_rdId == DE_rs1Id);

   wire E_M_fwd_rs2 = EM_wbEnable && (EM_rdId == DE_rs2Id);
   wire E_W_fwd_rs2 = MW_wbEnable && (MW_rdId == DE_rs2Id);

   wire [31:0] E_rs1 = E_M_fwd_rs1 ? EM_Eresult             :
	               E_W_fwd_rs1 ? wbData                 :
	                             RegisterBank[DE_rs1Id] ;

   wire [31:0] E_rs2 = E_M_fwd_rs2 ? EM_Eresult             :
	               E_W_fwd_rs2 ? wbData                 :
	                             RegisterBank[DE_rs2Id] ;

   /*********** the ALU *************************************************/

   wire [31:0] E_aluIn1 = E_rs1;
   wire [31:0] E_aluIn2 = (DE_isALUreg | DE_isBranch) ? E_rs2 : DE_IorSimm;
   wire [4:0]  E_shamt  = DE_isALUreg ? E_rs2[4:0] : DE_rs2Id;

   wire E_minus = DE_funct7[5] & DE_isALUreg;
   wire E_arith_shift = DE_funct7[5];

   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] E_aluPlus = E_aluIn1 + E_aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] E_aluMinus = {1'b1, ~E_aluIn2} + {1'b0,E_aluIn1} + 33'b1;
   wire        E_LT  =
                 (E_aluIn1[31] ^ E_aluIn2[31]) ? E_aluIn1[31] : E_aluMinus[32];
   wire        E_LTU = E_aluMinus[32];
   wire        E_EQ  = (E_aluIn1 == E_aluIn2);  // (E_aluMinus[31:0] == 0);

   // Flip a 32 bit word. Used by the shifter (a single shifter for
   // left and right shifts, saves silicium !)
   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

   wire [31:0] E_shifter_in = DE_funct3_is[1] ? flip32(E_aluIn1) : E_aluIn1;

   /* verilator lint_off WIDTH */
   wire [31:0] E_shifter =
       $signed({E_arith_shift & E_aluIn1[31], E_shifter_in}) >>> E_aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] E_leftshift = flip32(E_shifter);

   wire [31:0] E_aluOut_base =
	(DE_funct3_is[0] ? (E_minus ? E_aluMinus[31:0] : E_aluPlus) : 32'b0) |
	(DE_funct3_is[1] ? E_leftshift                              : 32'b0) |
	(DE_funct3_is[2] ? {31'b0, E_LT }                           : 32'b0) |
	(DE_funct3_is[3] ? {31'b0, E_LTU}                           : 32'b0) |
	(DE_funct3_is[4] ? E_aluIn1 ^ E_aluIn2                      : 32'b0) |
	(DE_funct3_is[5] ? E_shifter                                : 32'b0) |
	(DE_funct3_is[6] ? E_aluIn1 | E_aluIn2                      : 32'b0) |
	(DE_funct3_is[7] ? E_aluIn1 & E_aluIn2                      : 32'b0) ;

`ifdef CONFIG_RV32M

   /********** MUL **************/

   wire E_isMULH   = DE_funct3_is[1];
   wire E_isMULHSU = DE_funct3_is[2];

   wire E_mul_sign1 = E_rs1[31] &  E_isMULH;
   wire E_mul_sign2 = E_rs2[31] & (E_isMULH | E_isMULHSU);

   wire signed [32:0] E_mul_signed1 = {E_mul_sign1, E_rs1};
   wire signed [32:0] E_mul_signed2 = {E_mul_sign2, E_rs2};
   wire signed [63:0] E_multiply = E_mul_signed1 * E_mul_signed2;

   /********** DIV *************/
   // Heavily inspired by Claire Wolf's PicoRV.
   // Some ideas by Matthias Koch.

   reg [31:0] EE_dividend;
   reg [62:0] EE_divisor;
   reg [31:0] EE_quotient;
   reg [31:0] EE_quotient_msk;

   reg  EE_div_sign;
   reg 	EE_divBusy     = 1'b0;
   reg 	EE_divFinished = 1'b0;

   wire E_divstep_do = (EE_divisor <= {31'b0, EE_dividend});

   always @(posedge clk) begin
      if (!EE_divBusy) begin
	 if(DE_isDIV & !dataHazard & !EE_divFinished) begin
	    EE_quotient_msk <= 1 << 31;
	    EE_divBusy     <= 1'b1;
	 end
	 EE_dividend <=   ~DE_funct3[0] & E_rs1[31] ? -E_rs1 : E_rs1;
	 EE_divisor  <= {(~DE_funct3[0] & E_rs2[31] ? -E_rs2 : E_rs2), 31'b0};
	 EE_quotient <= 0;
	 EE_div_sign <= ~DE_funct3[0] & (DE_funct3[1] ? E_rs1[31] :
                         (E_rs1[31] != E_rs2[31]) & |E_rs2)       ;
      end else begin
	 EE_dividend <= E_divstep_do ? EE_dividend-EE_divisor[31:0]:EE_dividend;
	 EE_divisor  <= EE_divisor >> 1;
	 EE_quotient <= E_divstep_do ? EE_quotient|EE_quotient_msk :EE_quotient;
	 EE_quotient_msk <= EE_quotient_msk >> 1;
	 EE_divBusy <= EE_divBusy & !EE_quotient_msk[0];
      end
      EE_divFinished <= EE_quotient_msk[0];
   end

   wire [2:0] E_divsel = {DE_isDIV,DE_funct3[1],EE_div_sign};

   wire [31:0] E_aluOut_muldiv =
     (  DE_funct3_is[0]    ? E_multiply[31: 0] : 32'b0) | // 0:MUL
     ( |DE_funct3_is[3:1]  ? E_multiply[63:32] : 32'b0) | // 1:MH, 2:MHSU, 3:MHU
     (  E_divsel == 3'b100 ?  EE_quotient      : 32'b0) | // DIV
     (  E_divsel == 3'b101 ? -EE_quotient      : 32'b0) | // DIV (negative)
     (  E_divsel == 3'b110 ?  EE_dividend      : 32'b0) | // REM
     (  E_divsel == 3'b111 ? -EE_dividend      : 32'b0) ; // REM (negative)

   wire [31:0] E_aluOut = DE_isRV32M ? E_aluOut_muldiv : E_aluOut_base;

   wire aluBusy = EE_divBusy | (DE_isDIV & !EE_divFinished);

`else

   wire [31:0] E_aluOut = E_aluOut_base;
   wire aluBusy = 1'b0;

`endif

   /*********** Branch, JAL, JALR ***********************************/

   wire E_takeBranch =
        (DE_funct3_is[0] &  E_EQ ) | // BEQ
        (DE_funct3_is[1] & !E_EQ ) | // BNE
        (DE_funct3_is[4] &  E_LT ) | // BLT
        (DE_funct3_is[5] & !E_LT ) | // BGE
        (DE_funct3_is[6] &  E_LTU) | // BLTU
        (DE_funct3_is[7] & !E_LTU) ; // BGEU

   wire [31:0] E_JALRaddr = {E_aluPlus[31:1],1'b0};

`ifdef CONFIG_PC_PREDICT
 `ifdef CONFIG_RAS
     wire E_correctPC = (
	   (DE_isJALR    && (DE_predictRA != E_JALRaddr)   ) ||
           (DE_isBranch  && (E_takeBranch^DE_predictBranch))
     );
 `else
     wire E_correctPC = DE_isJALR ||
	(DE_isBranch  && (E_takeBranch^DE_predictBranch));
 `endif
   wire [31:0] E_PCcorrection = DE_isBranch ? DE_PCplus4orBimm : E_JALRaddr;
`else
   wire E_correctPC = (
			   DE_isJAL || DE_isJALR ||
			  (DE_isBranch && E_takeBranch)
			 );
   wire [31:0] E_PCcorrection =
	       DE_isJALR ? E_JALRaddr : DE_PCplusBorJimm;
`endif

   wire [31:0] E_result =
	       DE_isJALorJALRorLUIorAUIPC ? DE_PCplus4orUimm : E_aluOut;

   wire [31:0] E_addr = E_rs1 + DE_IorSimm;

   /**************************************************************/

`ifdef CONFIG_PC_PREDICT
 `ifdef CONFIG_GSHARE
   function [1:0] incdec_sat;
      input [1:0] prev;
      input dir;
      incdec_sat =
 	   {dir, prev} == 3'b000 ? 2'b00 :
           {dir, prev} == 3'b001 ? 2'b00 :
	   {dir, prev} == 3'b010 ? 2'b01 :
	   {dir, prev} == 3'b011 ? 2'b10 :
	   {dir, prev} == 3'b100 ? 2'b01 :
	   {dir, prev} == 3'b101 ? 2'b10 :
	   {dir, prev} == 3'b110 ? 2'b11 :
	                           2'b11 ;
   endfunction
 `endif
`endif

   always @(posedge clk) begin
      if(!E_stall) begin
	 EM_nop      <= DE_nop;
	 EM_rdId     <= DE_rdId;
	 EM_rs1Id    <= DE_rs1Id;
	 EM_rs2Id    <= DE_rs2Id;
	 EM_funct3   <= DE_funct3;
	 EM_csrId_is <= 4'b0001 << DE_csrId;
	 EM_rs2      <= E_rs2;
	 EM_Eresult  <= E_result;
	 EM_addr     <= E_addr;
	 EM_Mdata    <= DATARAM[E_addr[15:2]];
	 EM_isLoad   <= DE_isLoad;
	 EM_isStore  <= DE_isStore;
	 EM_isCSRRS  <= DE_isCSRRS;
	 EM_wbEnable <= DE_wbEnable && (DE_rdId != 0);
	 EM_correctPC  <= E_correctPC;
	 EM_PCcorrection <= E_PCcorrection;

`ifdef CONFIG_PC_PREDICT
 `ifdef CONFIG_GSHARE
	 if(DE_isBranch) begin
	    branch_history <= {E_takeBranch,branch_history[BP_HISTO_BITS-1:1]};
	    BHT[DE_BHTindex] <= incdec_sat(BHT[DE_BHTindex], E_takeBranch);
	 end
 `endif
`endif
      end
      if(M_flush) begin
	 EM_nop       <= 1'b1;
	 EM_isLoad    <= 1'b0;
	 EM_isStore   <= 1'b0;
	 EM_isCSRRS   <= 1'b0;
	 EM_wbEnable  <= 1'b0;
	 EM_correctPC <= 1'b0;
      end
   end

   assign halt = resetn & DE_isEBREAK;

/******************************************************************************/
/******************************************************************************/
   reg        EM_nop; // Needed by instret in W stage
   reg [4:0]  EM_rdId;
   reg [4:0]  EM_rs1Id;
   reg [4:0]  EM_rs2Id;
   (* onehot *) reg [3:0]  EM_csrId_is;
   reg [2:0]  EM_funct3;
   reg [31:0] EM_rs2;
   reg [31:0] EM_Eresult;
   reg [31:0] EM_addr;
   reg [31:0] EM_Mdata;
   reg        EM_isStore;
   reg        EM_isLoad;
   reg        EM_isCSRRS;
   reg 	      EM_wbEnable;
   reg        EM_correctPC;
   reg [31:0] EM_PCcorrection;

/******************************************************************************/
/******************************************************************************/

                     /*** M: Memory ***/

   wire M_isB = (EM_funct3[1:0] == 2'b00);
   wire M_isH = (EM_funct3[1:0] == 2'b01);

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
      if(M_wmask[0]) DATARAM[M_word_addr][ 7:0 ] <= M_STORE_data[ 7:0 ];
      if(M_wmask[1]) DATARAM[M_word_addr][15:8 ] <= M_STORE_data[15:8 ];
      if(M_wmask[2]) DATARAM[M_word_addr][23:16] <= M_STORE_data[23:16];
      if(M_wmask[3]) DATARAM[M_word_addr][31:24] <= M_STORE_data[31:24];
   end

   wire M_sext = !EM_funct3[2];

   /*************** LOAD ****************************/

   wire [15:0] M_LOAD_H=EM_addr[1] ? EM_Mdata[31:16]: EM_Mdata[15:0];
   wire  [7:0] M_LOAD_B=EM_addr[0] ? M_LOAD_H[15:8] : M_LOAD_H[7:0];
   wire        M_LOAD_sign=M_sext & (M_isB ? M_LOAD_B[7] : M_LOAD_H[15]);

   wire [31:0] M_Mdata = M_isB ? {{24{M_LOAD_sign}},M_LOAD_B} :
	                 M_isH ? {{16{M_LOAD_sign}},M_LOAD_H} :
                                                    EM_Mdata ;

   wire [31:0] M_CSR_data =
	(EM_csrId_is[0] ? cycle[31:0]    : 32'b0) |
	(EM_csrId_is[2] ? cycle[63:32]   : 32'b0) |
	(EM_csrId_is[1] ? instret[31:0]  : 32'b0) |
        (EM_csrId_is[3] ? instret[63:32] : 32'b0) ;

   initial begin
      $readmemh("DATARAM.hex",DATARAM);
   end

   always @(posedge clk) begin
      MW_nop       <= EM_nop;
      MW_rdId      <= EM_rdId;

      MW_wbData <=
	  EM_isLoad  ? (M_isIO ? IO_mem_rdata : M_Mdata) :
          EM_isCSRRS ? M_CSR_data   :
          EM_Eresult;

      MW_wbEnable  <= EM_wbEnable;

      if(!resetn) begin
	 instret <= 0;
      end else if(!MW_nop) begin
	 // It's easier to count the retired instructions when
	 // they *exit* the pipeline (but it requires to pass
	 // a _nop flag through the pipeline).
	 instret <= instret + 1;
      end
   end

/******************************************************************************/
/******************************************************************************/
   reg        MW_nop; // Needed by instret in W stage
   reg [4:0]  MW_rdId;
   reg [31:0] MW_wbData;
   reg 	      MW_wbEnable;
/******************************************************************************/
/******************************************************************************/

                     /*** W: WriteBack ***/

   assign wbData   = MW_wbData;
   assign wbEnable = MW_wbEnable;
   assign wbRdId   = MW_rdId;

/******************************************************************************/

   // we do not test rdId == 0 because in general, one loads data to
   // a register, not to zero !
   wire rs1Hazard = D_readsRs1 && (D_rs1Id == DE_rdId);
   wire rs2Hazard = D_readsRs2 && (D_rs2Id == DE_rdId);

   // we could generate slightly more bubble with
   // simpler test (to be used if critical path is here)
   // -> keeping this one (seems it has no influence on CPI,
   //   and results in slightly better timings)
   // wire  rs1Hazard = (D_rs1Id == DE_rdId);
   // wire  rs2Hazard = (D_rs2Id == DE_rdId);

   // we are not obliged to compare all bits !
   // wire rs1Hazard = (D_rs1Id[3:0] == DE_rdId[3:0]);
   // wire rs2Hazard = (D_rs2Id[3:0] == DE_rdId[3:0]);

   // Add bubble if next instr uses result of latency-2 instr
   // Or load right after store (problem only if same address,
   // we could also test but D does not know address yet)
   //  (we need here load after store test because mem read access is done
   //   in E. It was not the case in the non-optimized version)
   wire dataHazard = !FD_nop && (
        ((DE_isLoad || DE_isCSRRS) && (rs1Hazard || rs2Hazard)) ||
        ( D_isLoad && DE_isStore)
   );

   // (other option: always add bubble after latency-2 instr
   // like Samsoniuk's DarkRiscV). Increases CPI and may reduce critical path.
   // wire dataHazard = !FD_nop &&  (
   //   (DE_isLoad || DE_isCSRRS) || (D_isLoad && DE_isStore)
   // );

   assign F_stall = aluBusy | dataHazard | halt;
   assign D_stall = aluBusy | dataHazard | halt;
   assign E_stall = aluBusy;

   // Here we need to use E_correctPC (the registered version
   // DE_correctPC is not ready on time).
   assign D_flush = E_correctPC;
   assign E_flush = E_correctPC | dataHazard;
   assign M_flush = aluBusy;

   // Note: E_stall and M_flush are only used with the
   // multi-cycle ALU (RV32M)

/******************************************************************************/

`ifdef BENCH
   always @(posedge clk) begin
      if(halt) $finish();
   end

   reg [31:0] DE_instr; reg [31:0] DE_PC;
   reg [31:0] EM_instr; reg [31:0] EM_PC;
   reg [31:0] MW_instr; reg [31:0] MW_PC;

   localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

   always @(posedge clk) begin
      if(!D_stall) begin
	 DE_instr <= FD_nop ? NOP : FD_instr;
	 DE_PC    <= FD_PC;
      end
      if(E_flush) begin
	 DE_instr <= NOP;
      end
      if(!E_stall) begin
	 EM_instr <= DE_instr;
	 EM_PC    <= DE_PC;
      end
      if(M_flush) begin
	 EM_instr <= NOP;
      end
      MW_instr <= EM_instr;
      MW_PC    <= EM_PC;
   end

`ifdef CONFIG_DEBUG

   always @(posedge clk) begin
      if(resetn & !halt) begin

         $write("     ");
	 $write("[W] PC=%h ", MW_PC);
	 $write("     ");
	 riscv_disasm(MW_instr,MW_PC);
	 if(wbEnable) $write(
            "    x%0d <- 0x%0h (%0d)",
	    riscv_disasm_rdId(MW_instr),wbData,wbData
         );
	 $write("\n");

         $write("( %c) ",M_flush?"f":" ");
	 $write("[M] PC=%h ", EM_PC);
	 $write("     ");
	 riscv_disasm(EM_instr,EM_PC);
	 $write("\n");

         $write("(%c%c) ", E_stall ? "s" : " ", E_flush ? "f":" ");
	 $write("[E] PC=%h ", DE_PC);

	 // Register forwarding
	 if(DE_nop) $write("[  ] ");
	 else $write("[%s%s] ",
	         riscv_disasm_readsRs1(DE_instr) ?
		     (E_M_fwd_rs1 ? "M" : E_W_fwd_rs1 ? "W" : " ") : " ",
		 riscv_disasm_readsRs2(DE_instr) ?
		     (E_M_fwd_rs2 ? "M" : E_W_fwd_rs2 ? "W" : " ") : " "
	 );
	 riscv_disasm(DE_instr,DE_PC);
	 if(DE_instr != NOP) begin
	    $write("  rs1=0x%h (%0d) rs2=0x%h (%0d) ",E_rs1,E_rs1,E_rs2,E_rs2);
`ifdef CONFIG_PC_PREDICT
	    if(riscv_disasm_isBranch(DE_instr)) begin
	       $write(" taken:%0d  %s",
		       E_takeBranch,
		      (E_takeBranch == DE_predictBranch) ?
		             "predict hit" : "predict miss"
               );
	    end
`endif
	 end
`ifdef CONFIG_RV32M
	 if(DE_isRV32M) $write(" %d%d ",EE_divBusy, EE_divFinished);
	 if(aluBusy) $write(" %b",EE_quotient_msk);
`endif
	 $write("\n");

         $write("(%c%c) ",D_stall ? "s":" ",D_flush ? "f":" ");
	 $write("[D] PC=%h ", FD_PC);
	 $write("[%s%s] ",
		dataHazard && rs1Hazard?"*":" ",
		dataHazard && rs2Hazard?"*":" ");
	 riscv_disasm(FD_nop ? NOP : FD_instr,FD_PC);
`ifdef CONFIG_PC_PREDICT
	 if(riscv_disasm_isBranch(FD_instr)) begin
	    $write(" predict taken:%0d",D_predictBranch);
	 end
`endif
	 $write("\n");

         $write("(%c ) ",F_stall ? "s":" ");
	 $write("[F] PC=%h ", F_PC);
`ifdef CONFIG_PC_PREDICT
	 if(D_predictPC) begin
	    $write(" PC <- [D] 0x%0h (prediction)",D_PCprediction);
	 end
`endif
	 if(EM_correctPC) begin
	    $write(" PC <- [E] 0x%0h (correction)",EM_PCcorrection);
	 end
	 $write("\n");

	 $display("");
      end
   end

/* "debugger" */

`ifdef verilator

   // wire breakpoint = 1'b0; // no breakpoint
   // wire breakpoint = (EM_addr == 32'h400004); // break on LEDs output
   wire breakpoint = (EM_addr == 32'h400008); // break on character output
   // wire breakpoint = (DE_PC   == 32'h000000); // break on address reached
   // wire breakpoint = DE_isRV32M && DE_isALUreg;
   // wire breakpoint = DE_isDIV;

   reg step = 1'b1;
   reg [31:0] dbg_cmd = 0;

   initial begin
      $display("");
      $display("\"Debugger\" commands:");
      $display("--------------------");
      $display("g       : go");
      $display("<return>: step");
      $display("see \"debugger\" section in source for breakpoints");
      $display("");
   end

   always @(posedge clk) begin
      if(resetn & !halt) begin
	 if(step) begin
	    $write("DBG>");
	    dbg_cmd <= $c32("getchar()");
	    $write("\n");
	 end
	 if(dbg_cmd == "g") begin
	    step <= 1'b0;
	 end
	 if(breakpoint) begin
	    step <= 1'b1;
	 end
      end
   end
`endif

`endif // `CONFIG_DEBUG

   /*************** statistics *************/

   integer nbBranch = 0;
   integer nbBranchHit = 0;
   integer nbJAL  = 0;
   integer nbJALR = 0;
   integer nbJALRhit = 0;
   integer nbLoad = 0;
   integer nbStore = 0;
   integer nbLoadHazard = 0;
   integer nbRV32M = 0;
   integer nbMUL = 0;
   integer nbDIV = 0;

   always @(posedge clk) begin
      if(resetn & !D_stall) begin
	 if(riscv_disasm_isBranch(DE_instr)) begin
	    nbBranch <= nbBranch + 1;
`ifdef CONFIG_PC_PREDICT
	    if(E_takeBranch == DE_predictBranch) begin
	       nbBranchHit <= nbBranchHit + 1;
	    end
`endif
	 end
	 if(riscv_disasm_isJAL(DE_instr)) begin
	    nbJAL <= nbJAL + 1;
	 end
	 if(riscv_disasm_isJALR(DE_instr)) begin
	    nbJALR <= nbJALR + 1;
`ifdef CONFIG_RAS
	    if(DE_predictRA == E_JALRaddr) begin
	       nbJALRhit <= nbJALRhit + 1;
	    end
`endif
	 end
      end

      if(riscv_disasm_isLoad(MW_instr)) begin
	 nbLoad <= nbLoad + 1;
      end
      if(riscv_disasm_isStore(MW_instr)) begin
	 nbStore <= nbStore + 1;
      end
      if(riscv_disasm_isRV32M(MW_instr)) begin
	 if(MW_instr[14]) begin
	    nbDIV <= nbDIV + 1;
	 end else begin
	    nbMUL <= nbMUL + 1;
	 end
      end
      if(dataHazard) begin
	 nbLoadHazard <= nbLoadHazard + 1;
      end
   end

   /* verilator lint_off WIDTH */
   always @(posedge clk) begin
      if(halt) begin
	 $display("Simulated processor's report");
	 $display("----------------------------");
	 $display("Branch hit = %3.3f\%%",
		   nbBranchHit*100.0/nbBranch	 );
	 $display("JALR   hit = %3.3f\%%",
		   nbJALRhit*100.0/nbJALR	 );
	 $display("Load hzrds = %3.3f\%%", nbLoadHazard*100.0/nbLoad);
	 $display("CPI        = %3.3f",(cycle*1.0)/(instret*1.0));
	 $write("Instr. mix = (");
	 $write("Branch:%3.3f\%%",    nbBranch*100.0/instret);
	 $write(" JAL:%3.3f\%%",       nbJAL*100.0/instret);
	 $write(" JALR:%3.3f\%%",      nbJALR*100.0/instret);
	 $write(" Load:%3.3f\%%",      nbLoad*100.0/instret);
	 $write(" Store:%3.3f\%%",     nbStore*100.0/instret);
`ifdef CONFIG_RV32M
	 $write(" MUL(HSU):%3.3f\%% ", nbMUL*100.0/instret);
	 $write(" DIV/REM:%3.3f\%% ",   nbDIV*100.0/instret);
`endif
	 $write(")\n");
	 $finish();
      end
   end
   /* verilator lint_on WIDTH */

`endif // `BENCH

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
      .clk_freq_hz(`CPU_FREQ*1000000)
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
`ifdef CONFIG_DEBUG
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
