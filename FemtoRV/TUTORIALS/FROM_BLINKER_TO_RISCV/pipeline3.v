/**
 * pipeline2.v
 * Let us see how to morph our multi-cycle CPU into a pipelined CPU !
 * Step 3: "sequential pipeline"
 */
 
`default_nettype none
`include "clockworks.v"
`include "emitter_uart.v"

/******************************************************************************/

module ProgramMemory (
   input             clk,
   input      [15:0] mem_addr,  // address to be read
   output reg [31:0] mem_rdata  // data read from memory
);
   reg [31:0] MEM [0:16383]; // 16384 4-bytes words  
                             // 64 Kb of program RAM 
   wire [13:0] word_addr = mem_addr[15:2];
   always @(posedge clk) begin
      mem_rdata <= MEM[word_addr];
   end
   initial begin
      $readmemh("PROGROM.hex",MEM);
   end
endmodule

/******************************************************************************/

module DataMemory (
   input             clk,
   input      [15:0] mem_addr,  // address to be read
   output reg [31:0] mem_rdata, // data read from memory
   input      [31:0] mem_wdata, // data to be written
   input      [3:0]  mem_wmask	// masks for writing the 4 bytes (1=write byte)
);
   reg [31:0] MEM [0:16383]; // 16384 4-bytes words 
                             // 64 Kb of data RAM in total
   wire [13:0] word_addr = mem_addr[15:2];
   always @(posedge clk) begin
      mem_rdata <= MEM[word_addr];
      if(mem_wmask[0]) MEM[word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1]) MEM[word_addr][15:8 ] <= mem_wdata[15:8 ];
      if(mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
      if(mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];	 
   end
   initial begin
      $readmemh("DATARAM.hex",MEM);
   end
endmodule

/******************************************************************************/

module Processor (
    input 	  clk,
    input 	  resetn,
    output [31:0] prog_mem_addr,  // program memory address 
    input [31:0]  prog_mem_rdata, // data read from program memory
    output [31:0] data_mem_addr,  // data memory address
    input [31:0]  data_mem_rdata, // data read from data memory
    output [31:0] data_mem_wdata, // data written to data memory
    output [3:0]  data_mem_wmask  // write mask (1 bit per byte)
);

   /* state machine (will be removed when it will be a true pipeline) */
   
   localparam F_bit = 0; localparam F_state = 1 << F_bit;
   localparam D_bit = 1; localparam D_state = 1 << D_bit;
   localparam E_bit = 2; localparam E_state = 1 << E_bit;
   localparam M_bit = 3; localparam M_state = 1 << M_bit;
   localparam W_bit = 4; localparam W_state = 1 << W_bit;

   reg [4:0] 	  state;
   reg   	  ebreak;
   
   always @(posedge clk) begin
      if(!resetn) begin
	 state  <= F_state;
      end else if(!ebreak) begin
	 state <= {state[3:0],state[4]};
      end
   end

/******************************************************************************/

   reg [63:0] cycle;   
   reg [63:0] instret;

   always @(posedge clk) begin
      cycle <= !resetn ? 0 : cycle + 1;
   end
   
/******************************************************************************/

/******************************************************************************/
   
                      /***  F: Instruction fetch ***/   

   reg  [31:0] 	  F_PC;
   wire [31:0] 	  F_jumpOrBranchAddress;
   wire 	  F_jumpOrBranch;

   assign prog_mem_addr = F_PC;
   
   always @(posedge clk) begin
      FD_instr <= prog_mem_rdata;
      FD_PC    <= F_PC;
      if(!resetn) begin
	 F_PC    <= 0;
	 instret <= 0;
      end else begin
	 if(state[F_bit]) begin
	    F_PC     <= F_PC+4;
	    instret  <= instret + 1;
	 end else if(state[M_bit] & F_jumpOrBranch) begin
	    F_PC  <= F_jumpOrBranchAddress;
	 end 
      end
   end

/******************************************************************************/
   reg [31:0] FD_PC;   
   reg [31:0] FD_instr;
   
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
      if(state[D_bit]) begin
	 DE_rs1 <= RegisterBank[D_rs1Id];
	 DE_rs2 <= RegisterBank[D_rs2Id];
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
      end
   end
   
/******************************************************************************/
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
   reg [1:0]  DE_CSR; // 11: instreth, 01: instret, 10: cycleh, 01: cycle

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

   /***************************************************************************/
   
   always @(posedge clk) begin
      if(state[E_bit]) begin
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
	 if(DE_isBranch) begin
	    /* verilator lint_off CASEINCOMPLETE */	    
	    case (DE_funct3)
	      3'b000: EM_JumpOrBranch <= E_EQ;
	      3'b001: EM_JumpOrBranch <= !E_EQ;
	      3'b100: EM_JumpOrBranch <= E_LT;
	      3'b101: EM_JumpOrBranch <= !E_LT;
	      3'b110: EM_JumpOrBranch <= E_LTU;
	      3'b111: EM_JumpOrBranch <= !E_LTU;
	    endcase 
	    /* verilator lint_on CASEINCOMPLETE */	    
	 end else begin 
	    EM_JumpOrBranch <= DE_isJAL || DE_isJALR;
	 end 

	 EM_Eresult <= (DE_isJAL || DE_isJALR) ? E_PCplus4   :
			      DE_isLUI         ? DE_imm      :
			      DE_isAUIPC       ? E_PCplusImm :
			                         E_aluOut    ;
	 
	 EM_addr <= (DE_isBranch || DE_isJAL) ? E_PCplusImm            :
  		        DE_isJALR             ? {E_aluPlus[31:1],1'b0} :
 		                                 E_loadstore_addr      ;

	 EM_funct3  <= DE_funct3;
	 EM_CSR     <= DE_CSR;
      end
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
/******************************************************************************/

                     /*** M: Memory ***/

   // E_ and not EM_ because we need to have it one cycle before
   assign data_mem_addr = E_loadstore_addr; 
   wire M_isB = (EM_funct3[1:0] == 2'b00);
   wire M_isH = (EM_funct3[1:0] == 2'b01);

   /*************** LOAD ****************************/
   
   wire [15:0] M_LOAD_H=EM_addr[1]? data_mem_rdata[31:16]: data_mem_rdata[15:0];
   wire  [7:0] M_LOAD_B=EM_addr[0] ? M_LOAD_H[15:8] : M_LOAD_H[7:0];
   wire        M_LOAD_sign=!EM_funct3[2] & (M_isB ? M_LOAD_B[7] : M_LOAD_H[15]);

   wire [31:0] M_LOAD_data = M_isB ? {{24{M_LOAD_sign}},M_LOAD_B} :
	                     M_isH ? {{16{M_LOAD_sign}},M_LOAD_H} :
                                                   data_mem_rdata ;
   
   /*************** STORE **************************/

   assign data_mem_wdata[ 7: 0] = EM_rs2[7:0];
   assign data_mem_wdata[15: 8] = EM_addr[0] ? EM_rs2[7:0]  : EM_rs2[15: 8] ;
   assign data_mem_wdata[23:16] = EM_addr[1] ? EM_rs2[7:0]  : EM_rs2[23:16] ;
   assign data_mem_wdata[31:24] = EM_addr[0] ? EM_rs2[7:0]  :
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

   assign data_mem_wmask = {4{(state[W_bit]) & EM_isStore}} & M_STORE_wmask;

   always @(posedge clk) begin
      if(state[M_bit]) begin
	 MW_wb_enable <= EM_wb_enable;
	 MW_rdId      <= EM_rdId;
	 MW_Mresult   <= M_LOAD_data;
	 MW_Eresult   <= EM_Eresult;
	 MW_isLoad    <= EM_isLoad;
	 MW_isCSRRS   <= EM_isCSRRS;
	 MW_CSR       <= EM_CSR;
      end
   end

/******************************************************************************/
   reg        MW_wb_enable;
   reg [4:0]  MW_rdId;
   reg [31:0] MW_Eresult;   
   reg [31:0] MW_Mresult;
   reg        MW_isLoad;
   reg        MW_isCSRRS;
   reg [1:0]  MW_CSR;
/******************************************************************************/

                     /*** W: WriteBack ***/

   reg [31:0] W_CSRdata;
   always @(*) begin
      case(MW_CSR) 
	 2'b00: W_CSRdata = cycle[31:0];
	 2'b10: W_CSRdata = cycle[63:32];
	 2'b01: W_CSRdata = instret[31:0];
	 2'b11: W_CSRdata = instret[63:32];	 
      endcase
   end
	       
   wire [31:0] W_wb_data = 
	       MW_isLoad  ? MW_Mresult :
	       MW_isCSRRS ? W_CSRdata  :
	       MW_Eresult;
   
   always @(posedge clk) begin
      if(state[W_bit]) begin
	 if(MW_wb_enable) begin
	    RegisterBank[MW_rdId] <= W_wb_data;
	 end
      end
   end

/******************************************************************************/
   assign F_jumpOrBranchAddress = EM_addr;
   assign F_jumpOrBranch        = EM_JumpOrBranch;
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

   wire [31:0] prog_mem_addr;
   wire [31:0] prog_mem_rdata;
   
   wire [31:0] data_mem_addr;
   wire [31:0] data_mem_rdata;
   wire [31:0] data_mem_wdata;
   wire [3:0]  data_mem_wmask;

   Processor CPU(
      .clk(clk),
      .resetn(resetn),
      .prog_mem_addr(prog_mem_addr),
      .prog_mem_rdata(prog_mem_rdata),
      .data_mem_addr(data_mem_addr),
      .data_mem_rdata(data_mem_rdata),
      .data_mem_wdata(data_mem_wdata),
      .data_mem_wmask(data_mem_wmask)
   );

   /*
    * Memory map: three pages of 64kB each
    *   page 0: instruction mem (readonly)
    *   page 1: data mem        (readwrite)
    *   page 2: IO              (readwrite)
    *
    *  mem_addr[15:0] : offset in page
    *  mem_addr[16]   : data / code
    *  mem_addr[22]   : IO (same bit as the rest of this tutorial)
    */
   
   wire [31:0] RAM_rdata;
   wire [13:0] mem_wordaddr = data_mem_addr[15:2];
   wire        isIO         = data_mem_addr[22];
   wire        isRAM        = !isIO;
   wire        mem_wstrb    = |data_mem_wmask;

   ProgramMemory progROM(
      .clk(clk),
      .mem_addr(prog_mem_addr[15:0]),
      .mem_rdata(prog_mem_rdata)
   );
   
   DataMemory RAM(
      .clk(clk),
      .mem_addr(data_mem_addr[15:0]),
      .mem_rdata(RAM_rdata),
      .mem_wdata(data_mem_wdata),
      .mem_wmask({4{isRAM}}&data_mem_wmask)
   );
   
   // Memory-mapped IO in IO page, 1-hot addressing in word address.   
   localparam IO_LEDS_bit      = 0;  // W five leds
   localparam IO_UART_DAT_bit  = 1;  // W data to send (8 bits) 
   localparam IO_UART_CNTL_bit = 2;  // R status. bit 9: busy sending
   
   always @(posedge clk) begin
      if(isIO & mem_wstrb & mem_wordaddr[IO_LEDS_bit]) begin
	 LEDS <= data_mem_wdata[4:0];
      end
   end

   wire uart_valid = isIO & mem_wstrb & mem_wordaddr[IO_UART_DAT_bit];
   wire uart_ready;

   corescore_emitter_uart #(
      .clk_freq_hz(`CPU_FREQ*1000000),
        .baud_rate(1000000)
   ) UART(
      .i_clk(clk),
      .i_rst(!resetn),
      .i_data(data_mem_wdata[7:0]),
      .i_valid(uart_valid),
      .o_ready(uart_ready),
      .o_uart_tx(TXD)      			       
   );
   
   wire [31:0] IO_rdata = 
	       mem_wordaddr[IO_UART_CNTL_bit] ? { 22'b0, !uart_ready, 9'b0}
	                                      : 32'b0;

   assign data_mem_rdata = isRAM ? RAM_rdata : IO_rdata ;

`ifdef BENCH
   always @(posedge clk) begin
      if(uart_valid) begin
	 $write("%c", data_mem_wdata[7:0] );
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

 
