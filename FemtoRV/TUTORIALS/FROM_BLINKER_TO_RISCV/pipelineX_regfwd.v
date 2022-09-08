/**
 * pipeline6.v
 * Let us see how to morph our multi-cycle CPU into a pipelined CPU !
 * Step X: Simplify for higher maxfreq and smaller area
 *   - register forwarding
 *   TODO: reintegrate branch prediction and return address stack
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

                      /***  F: Instruction fetch ***/   

   reg  [31:0] 	  PC;

   reg [31:0] PROGROM[0:16383]; // 16384 4-bytes words  
                                // 64 Kb of program ROM 
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

   wire [31:0] F_PC = EM_JumpOrBranchNow ? EM_JumpOrBranchAddr : PC;
   
   always @(posedge clk) begin

      if(!F_stall) begin
	 FD_instr <= PROGROM[F_PC[15:2]]; 
	 FD_PC    <= F_PC;
	 PC       <= F_PC+4;
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
// wire D_isLoad   = (FD_instr[6:2]==5'b00000); 
   wire D_isALUreg = (FD_instr[6:2]==5'b01100); 
   wire D_isALUimm = (FD_instr[6:2]==5'b00100); 
   wire D_isStore  = (FD_instr[6:2]==5'b01000); 
   wire D_isSYSTEM = (FD_instr[6:2]==5'b11100);

   // optimized codop recognizers
   wire D_isJAL    = FD_instr[3]; 
   wire D_isJALR   = {FD_instr[6], FD_instr[3], FD_instr[2]} == 3'b101; 
   wire D_isLUI    = FD_instr[6:4] == 3'b111; 
   wire D_isAUIPC  = FD_instr[6:4] == 3'b101; 
   wire D_isBranch = {FD_instr[6], FD_instr[4], FD_instr[2]} == 3'b100; 
   wire D_isLoad   = !|FD_instr[6:2];
   
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

   reg [31:0] RegisterBank [0:31];
   always @(posedge clk) begin

      DE_rdId  <= D_rdId;
      DE_rs1Id <= D_rs1Id;
      DE_rs2Id <= D_rs2Id;

      DE_funct3    <= FD_instr[14:12];
      DE_funct3_is <= 8'b00000001 << FD_instr[14:12];
      DE_funct7    <= FD_instr[30];
      DE_csrId     <= {FD_instr[27],FD_instr[21]};

      DE_nop <= 1'b0;
      
      if(!D_stall) begin
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
      end
      
      if(wbEnable) begin
	 RegisterBank[wbRdId] <= wbData;
      end

      DE_IorSimm <= {
		     {21{FD_instr[31]}}, 
		     D_isStore ? {FD_instr[30:25],FD_instr[11:7]} : 
			          FD_instr[30:20]
		    };

      // DE_PCplus4orUimm = 
      //    ((isLUI ? 0 : FD_PC)) + ((isJAL | isJALR) ? 4 : Uimm)
      // (knowing that isLUI | isAUIPC | isJAL | isJALR)
      DE_PCplus4orUimm <= ({32{FD_instr[6:5]!=2'b01}} & FD_PC) + 
                          (D_isJALorJALR ? 4 : D_Uimm);


      DE_PCplusBorJimm <= FD_PC + (D_isJAL ? D_Jimm : D_Bimm);
      
      DE_isJALorJALRorLUIorAUIPC <= FD_instr[2];
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

   reg DE_wbEnable; // !isBranch && !isStore && rdId != 0

   reg DE_isJALorJALRorLUIorAUIPC;

   reg [31:0] DE_PCplus4orUimm;
   reg [31:0] DE_PCplusBorJimm;
   
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

   wire [31:0] E_shifter_in = (DE_funct3==3'b001) ? flip32(E_aluIn1) : E_aluIn1;
   
   /* verilator lint_off WIDTH */
   wire [31:0] E_shifter = 
       $signed({E_arith_shift & E_aluIn1[31], E_shifter_in}) >>> E_aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] E_leftshift = flip32(E_shifter);

   wire [31:0] E_aluOut = 
	(DE_funct3_is[0] ? (E_minus ? E_aluMinus[31:0] : E_aluPlus) : 32'b0) |
	(DE_funct3_is[1] ? E_leftshift                              : 32'b0) |
	(DE_funct3_is[2] ? {31'b0, E_LT }                           : 32'b0) |
	(DE_funct3_is[3] ? {31'b0, E_LTU}                           : 32'b0) |
	(DE_funct3_is[4] ? E_aluIn1 ^ E_aluIn2                      : 32'b0) |
	(DE_funct3_is[5] ? E_shifter                                : 32'b0) |
	(DE_funct3_is[6] ? E_aluIn1 | E_aluIn2                      : 32'b0) |
	(DE_funct3_is[7] ? E_aluIn1 & E_aluIn2                      : 32'b0) ;
   

   /*********** Branch, JAL, JALR ***********************************/

   wire E_takeBranch = 
        (DE_funct3_is[0] &  E_EQ ) | // BEQ
        (DE_funct3_is[1] & !E_EQ ) | // BNE
        (DE_funct3_is[4] &  E_LT ) | // BLT
        (DE_funct3_is[5] & !E_LT ) | // BGE
        (DE_funct3_is[6] &  E_LTU) | // BLTU
        (DE_funct3_is[7] & !E_LTU) ; // BGEU

   wire E_JumpOrBranch = (
			   DE_isJAL || DE_isJALR || 
			  (DE_isBranch && E_takeBranch)
			 );

   wire [31:0] E_JumpOrBranchAddr = 
	       DE_isJALR ? {E_aluPlus[31:1],1'b0} : DE_PCplusBorJimm;
    
   wire [31:0] E_result =
	       DE_isJALorJALRorLUIorAUIPC ? DE_PCplus4orUimm : E_aluOut; 

   wire [31:0] E_addr = E_rs1 + DE_IorSimm;
   
   /**************************************************************/
   
   always @(posedge clk) begin
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
      EM_JumpOrBranchNow  <= E_JumpOrBranch;
      EM_JumpOrBranchAddr <= E_JumpOrBranchAddr;
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
   reg        EM_JumpOrBranchNow;
   reg [31:0] EM_JumpOrBranchAddr;
   
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
//   wire  rs1Hazard = (D_rs1Id == DE_rdId);
//   wire  rs2Hazard = (D_rs2Id == DE_rdId);
   
   // we are not obliged to compare all bits ! 
   // wire rs1Hazard = (D_rs1Id[3:0] == DE_rdId[3:0]);
   // wire rs2Hazard = (D_rs2Id[3:0] == DE_rdId[3:0]);
   
   // Add bubble only if next instr uses result of latency-2 instr
   wire dataHazard = !FD_nop && (DE_isLoad || DE_isCSRRS) && 
   	             (rs1Hazard || rs2Hazard); 

   // (other option: always add bubble after latency-2 instr 
   // like Samsoniuk's DarkRiscV). Reduces critical path.
   // wire dataHazard = !FD_nop && (DE_isLoad || DE_isCSRRS);
   
   assign F_stall = dataHazard | halt;
   assign D_stall = dataHazard | halt;

   // Here we need to use E_JumpOrBranch (the registered version
   // DE_JumpOrBranch is not ready on time).
   assign D_flush = E_JumpOrBranch;
   assign E_flush = E_JumpOrBranch | dataHazard;

/******************************************************************************/

`ifdef BENCH
   always @(posedge clk) begin
      if(halt) $finish();
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

 
