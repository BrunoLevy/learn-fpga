/**
 * pipeline4.v
 * Let us see how to morph our multi-cycle CPU into a pipelined CPU !
 * Step 4: stalling and bubbles
 * *** BROKEN ***
 *   Debugging strategy:
 *     1) ignore data hazards for now
 *     2) implement stalling for branch/jump
 *     3) add "bubble" attribute for each stage
 *     4) debug: display all states + bubble status
 *     5) implement stalling for data hazard
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
   
   reg ebreak; // TODO
   
/******************************************************************************/

   
   reg [63:0] cycle;   
   reg [63:0] instret;

   always @(posedge clk) begin
      cycle <= !resetn ? 0 : cycle + 1;
   end
   
/******************************************************************************/

   localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;
   
                      /***  F: Instruction fetch ***/   

   reg  [31:0] 	  F_PC;
   wire [31:0] 	  jumpOrBranchAddress;
   wire 	  jumpOrBranch;

   reg [31:0] PROGROM[0:16383]; // 16384 4-bytes words  
                                // 64 Kb of program ROM 
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

   always @(posedge clk) begin
      if(!resetn) begin
	 F_PC    <= 0;
	 instret <= 0;
	 FD_instr <= NOP;
      end else begin
	 FD_instr <= PROGROM[F_PC[15:2]];
	 FD_PC    <= F_PC;
	 F_PC     <= jumpOrBranch ? jumpOrBranchAddress : F_PC+4;
      end
      FD_bubble <= jumpOrBranch;
   end
   
/******************************************************************************/
   reg [31:0] FD_PC;   
   reg [31:0] FD_instr;
   reg        FD_bubble;
/******************************************************************************/

                     /*** D: Instruction decode ***/

   reg [31:0] RegisterBank [0:31];
   
   // The 10 RISC-V instructions
   wire D_isALUreg  = (FD_instr[6:2] == 5'b01100); // rd <- rs1 OP rs2   
   wire D_isALUimm  = (FD_instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   wire D_isBranch  = (FD_instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   wire D_isJALR    = (FD_instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire D_isJAL     = (FD_instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   wire D_isAUIPC   = (FD_instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire D_isLUI     = (FD_instr[6:2] == 5'b01101); // rd <- Uimm   
   wire D_isLoad    = (FD_instr[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   wire D_isStore   = (FD_instr[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   wire D_isSYSTEM  = (FD_instr[6:2] == 5'b11100); // EBREAK and CSRRS
   
   // The 5 immediate formats 
   // // (TODO: mutualize sign extend, postpone shift by 1 in Bimm and Jimm)
   wire [31:0] D_Uimm={    FD_instr[31],   FD_instr[30:12], {12{1'b0}}};
   wire [31:0] D_Iimm={{21{FD_instr[31]}}, FD_instr[30:20]};
   wire [31:0] D_Simm={{21{FD_instr[31]}}, FD_instr[30:25],FD_instr[11:7]};
   wire [31:0] D_Bimm={
	  {20{FD_instr[31]}},FD_instr[7],FD_instr[30:25],FD_instr[11:8],1'b0
   };
   wire [31:0] D_Jimm={
          {12{FD_instr[31]}},FD_instr[19:12],FD_instr[20],FD_instr[30:21],1'b0
   };
   
   // TODO: optimize 
   wire [31:0] D_imm =
	       (D_isAUIPC  | D_isLUI)             ? D_Uimm :
	       (D_isALUimm | D_isJALR | D_isLoad) ? D_Iimm :
	        D_isStore                         ? D_Simm :
	        D_isBranch                        ? D_Bimm :
 	                                            D_Jimm ;
   
   wire [4:0] D_rs1Id = FD_instr[19:15];
   wire [4:0] D_rs2Id = FD_instr[24:20];
   wire [4:0] D_rdId  = FD_instr[11:7];

   wire [2:0] D_funct3 = FD_instr[14:12];
   wire [6:0] D_funct7 = FD_instr[31:25];

   wire D_isEBREAK = D_isSYSTEM & (D_funct3 == 3'b000);
   wire D_isCSRRS  = D_isSYSTEM & (D_funct3 == 3'b010);
   
   always @(posedge clk) begin
      DE_rs1 <= RegisterBank[D_rs1Id];
      DE_rs2 <= RegisterBank[D_rs2Id];
      DE_rs1Id       <= D_rs1Id;
      DE_rs2Id       <= D_rs2Id;
      DE_rs1z        <= (D_rs1Id == 0);
      DE_rs2z        <= (D_rs2Id == 0);
      DE_imm         <= D_imm;
      DE_rdId        <= D_rdId;
      DE_wb_enable   <= !(D_isBranch || D_isStore) && (D_rdId != 5'b0);
      DE_PC          <= FD_PC;
      DE_isALUreg    <= D_isALUreg;
      DE_isALUimm    <= D_isALUimm;
      DE_isBranch    <= D_isBranch;
      DE_isJALR      <= D_isJALR;
      DE_isJAL       <= D_isJAL;
      DE_isAUIPC     <= D_isAUIPC;
      DE_isLUI       <= D_isLUI;
      DE_isLoad      <= D_isLoad;
      DE_isStore     <= D_isStore;
      DE_isCSRRS     <= D_isCSRRS;
      DE_funct3      <= D_funct3;
      DE_minus       <= D_funct7[5] & D_isALUreg;
      DE_arith_shift <= FD_instr[30];
      DE_shamt       <= FD_instr[24:20];
      DE_CSR         <= {FD_instr[27],FD_instr[21]};
      ebreak         <= !resetn ? 0 : D_isEBREAK;
      DE_bubble      <= FD_bubble | jumpOrBranch;
      DE_instr       <= FD_instr;
   end
   
/******************************************************************************/
   reg [4:0]  DE_rs1Id;
   reg [4:0]  DE_rs2Id;
   reg        DE_rs1z;
   reg        DE_rs2z;
   reg [31:0] DE_rs1;
   reg [31:0] DE_rs2;
   reg [31:0] DE_imm;
   reg        DE_wb_enable;
   reg [4:0]  DE_rdId;
   reg [31:0] DE_PC;
   reg 	      DE_isALUreg;
   reg 	      DE_isALUimm;
   reg 	      DE_isBranch;
   reg 	      DE_isJALR;
   reg 	      DE_isJAL;
   reg 	      DE_isAUIPC;
   reg 	      DE_isLUI;
   reg 	      DE_isLoad;
   reg 	      DE_isStore;
   reg 	      DE_isCSRRS;
   reg [2:0]  DE_funct3;
   reg        DE_minus;
   reg        DE_arith_shift;
   reg [4:0]  DE_shamt;
   reg [1:0]  DE_CSR; // 11: instret, 01: instret, 10: cycleh, 01: cycle
   reg        DE_bubble;
   reg [31:0] DE_instr; // for debugging
   
/******************************************************************************/

                     /*** E: Execute ***/

   /*********** the ALU *************************************************/
   
   wire [31:0] E_aluIn1 = DE_rs1;
   wire [31:0] E_aluIn2 = (DE_isALUreg | DE_isBranch) ? DE_rs2 : DE_imm;

   wire [4:0] E_shamt = DE_isALUreg ? DE_rs2[4:0] : DE_shamt; // shift amount

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
       $signed({DE_arith_shift & E_aluIn1[31], E_shifter_in}) >>> E_aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] E_leftshift = flip32(E_shifter);

   reg [31:0] E_aluOut;
   always @(*) begin
      case(DE_funct3)
	3'b000: E_aluOut = DE_minus ? E_aluMinus[31:0] : E_aluPlus;
	3'b001: E_aluOut = E_leftshift;
	3'b010: E_aluOut = {31'b0, E_LT};
	3'b011: E_aluOut = {31'b0, E_LTU};
	3'b100: E_aluOut = E_aluIn1 ^ E_aluIn2;
	3'b101: E_aluOut = E_shifter;
	3'b110: E_aluOut = E_aluIn1 | E_aluIn2;
	3'b111: E_aluOut = E_aluIn1 & E_aluIn2;
      endcase
   end
   
   /*********** Address computation *******************************************/

   wire [31:0] E_PCplusImm      = DE_PC + DE_imm;
   wire [31:0] E_PCplus4        = DE_PC + 4;
   wire [31:0] E_loadstore_addr = E_aluPlus; // DE_rs1 + DE_imm;

   reg E_takeBranch;
   always @(*) begin
      case (DE_funct3)
	3'b000: E_takeBranch = E_EQ;
	3'b001: E_takeBranch = !E_EQ;
	3'b100: E_takeBranch = E_LT;
	3'b101: E_takeBranch = !E_LT;
	3'b110: E_takeBranch = E_LTU;
	3'b111: E_takeBranch = !E_LTU;
	default: E_takeBranch = 1'b0;
      endcase 
   end
   
   
   wire E_JumpOrBranch = DE_isJAL || DE_isJALR || 
 	                     (DE_isBranch && E_takeBranch);
   
   /***************************************************************************/
   
   always @(posedge clk) begin
	 EM_rs2       <= DE_rs2;
	 EM_wb_enable <= DE_wb_enable;
	 EM_rdId      <= DE_rdId;
	 EM_isLoad    <= DE_isLoad;
	 EM_isStore   <= DE_isStore;
	 EM_isCSRRS   <= DE_isCSRRS;

	 EM_Eresult <= (DE_isJAL | DE_isJALR)      ? E_PCplus4   :
  		        DE_isLUI                   ? DE_imm      :
		        DE_isAUIPC                 ? E_PCplusImm : 
                                                     E_aluOut    ;

         EM_JumpOrBranch <= E_JumpOrBranch;
      
	 EM_Eresult <= (DE_isJAL || DE_isJALR) ? E_PCplus4   :
			      DE_isLUI         ? DE_imm      :
			      DE_isAUIPC       ? E_PCplusImm :
			                         E_aluOut    ;
	 
	 EM_addr <= (DE_isBranch || DE_isJAL) ? E_PCplusImm            :
  		        DE_isJALR             ? {E_aluPlus[31:1],1'b0} :
 		                                 E_loadstore_addr      ;

	 EM_funct3  <= DE_funct3;
	 EM_CSR     <= DE_CSR;
         EM_bubble  <= DE_bubble;
         EM_PC      <= DE_PC;
         EM_instr   <= DE_instr;
   end
   
/******************************************************************************/
   reg [31:0] EM_rs2;
   reg        EM_wb_enable;
   reg [4:0]  EM_rdId;
   reg [31:0] EM_Eresult;
   reg [31:0] EM_addr;
   reg [2:0]  EM_funct3;
   reg 	      EM_JumpOrBranch;
   reg        EM_isLoad;
   reg        EM_isStore;
   reg        EM_isCSRRS;
   reg [1:0]  EM_CSR;
   reg        EM_bubble;
   reg [31:0] EM_PC; // for debugging
   reg [31:0] EM_instr; // for debugging
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

   wire [3:0] M_wmask = {4{EM_isStore & M_isRAM & !EM_bubble}} & M_STORE_wmask;
   
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
      MW_wb_enable <= EM_wb_enable;
      MW_rdId      <= EM_rdId;
      MW_Eresult   <= EM_Eresult;
      MW_isLoad    <= EM_isLoad;
      MW_isCSRRS   <= EM_isCSRRS;
      MW_isIO      <= M_isIO;
      MW_IOresult  <= IO_mem_rdata;
      MW_addr      <= EM_addr[1:0];
      MW_isB       <= M_isB;
      MW_isH       <= M_isH;
      MW_sext      <= !EM_funct3[2];
      case(EM_CSR) 
	2'b00: MW_CSRresult = cycle[31:0];
	2'b10: MW_CSRresult = cycle[63:32];
	2'b01: MW_CSRresult = instret[31:0];
	2'b11: MW_CSRresult = instret[63:32];	 
      endcase // case (EM_CSR)
      MW_bubble <= EM_bubble;
      MW_PC     <= EM_PC;
      MW_instr  <= EM_instr;
   end

/******************************************************************************/
   reg        MW_wb_enable;
   reg [4:0]  MW_rdId;
   reg [31:0] MW_Eresult;   
   reg [31:0] MW_Mdata;
   reg [31:0] MW_IOresult;   
   reg        MW_isLoad;
   reg        MW_isCSRRS;
   reg [31:0] MW_CSRresult;
   reg        MW_isIO;
   reg [1:0]  MW_addr;
   reg        MW_isB, MW_isH;
   reg        MW_sext;
   reg        MW_bubble;
   reg [31:0] MW_PC; // for debugging
   reg [31:0] MW_instr; // for debugging
/******************************************************************************/

                     /*** W: WriteBack ***/

   /*************** LOAD ****************************/
   
   wire [15:0] W_LOAD_H=MW_addr[1] ? MW_Mdata[31:16]: MW_Mdata[15:0];
   wire  [7:0] W_LOAD_B=MW_addr[0] ? W_LOAD_H[15:8] : W_LOAD_H[7:0];
   wire        W_LOAD_sign=MW_sext & (MW_isB ? W_LOAD_B[7] : W_LOAD_H[15]);

   wire [31:0] W_Mresult = MW_isB ? {{24{W_LOAD_sign}},W_LOAD_B} :
	                   MW_isH ? {{16{W_LOAD_sign}},W_LOAD_H} :
                                                        MW_Mdata ;
   wire [31:0] W_wb_data = 
	       MW_isLoad  ? (MW_isIO ? MW_IOresult : W_Mresult) :
	       MW_isCSRRS ? MW_CSRresult :
	       MW_Eresult;
   
   always @(posedge clk) begin
      if(MW_wb_enable && !MW_bubble) begin
	 RegisterBank[MW_rdId] <= W_wb_data;
      end
   end

/******************************************************************************/
   assign jumpOrBranchAddress = EM_addr;
   assign jumpOrBranch        = EM_JumpOrBranch;
/******************************************************************************/

   always @(posedge clk) begin
      if(resetn) begin
	 
	 $display("[F] PC=%h JoB=%d JoBaddr=%h ",F_PC, 
		  jumpOrBranch, jumpOrBranchAddress
         );
	 
	 $write("[D] PC=%h B=%d ", FD_PC, FD_bubble); 
	 riscv_disasm(FD_instr,FD_PC);
	 $write("\n");

	 $write("[E] PC=%h B=%d ", DE_PC, DE_bubble); 
	 riscv_disasm(DE_instr,DE_PC);
	 $write("\n");

	 $write("[M] PC=%h B=%d ", EM_PC, EM_bubble); 
	 riscv_disasm(EM_instr,EM_PC);
	 $write("\n");

	 $write("[W] PC=%h B=%d ", MW_PC, MW_bubble); 
	 riscv_disasm(MW_instr,MW_PC);
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

 
