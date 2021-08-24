/******************************************************************************/
// FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
//
// This version: PetitBateau (make it float), under development (RV32F)

// [DONE] Preparation: compile and inspect RV32F instructions used in asm
// [DONE] simulated FPU + FPU instruction decoder tested in Verilator 
//             with mandel_float and tinyraytracer
//
// [DONE] wired FPU, mandel_float -O0
//  *  FADD
//  *  FLT
//  *  FMUL
//  *  FSUB
//   (FCVT.S.WU and FSGNJ if dx/dy given by expression instead of by value) 
// [DONE] wired FPU, mandel_float -O3
//  *  FMADD
//  *  FMSUB
//  *  FSGNJ
// [DONE] wired FPU, tinyraytracer -O0
//  *  FCVT.W.S
//  *  FCVT.WU.S
//  *  FDIV
//  *  FSGNJ
//  *  FSGNJN
//  *  FSGNJX
// [DONE] wired FPU, tinyraytracer -O3
//  *  FNMSUB
//  *  FSQRT
// [TODO] wired FPU, full instr set
//  *  FNMADD
//    FMIN
//    FMAX
//  *  FMV.X.W
//  *  FEQ
//  *  FLE
//    FCLASS
//  *  FCVT.S.W
//  *  FCVT.S.WU
//  *  FMV.W.X
// [TODO] add FPU CSR (and instret for perf stat)]
// [TODO] FSW/FLW unaligned (does not seem to occur, but the norm requires it)
//
// [DONE] fast leading zero count:
// https://electronics.stackexchange.com/questions/196914/verilog-synthesize-high-speed-leading-zero-count
// (thanks @NickTernovoy)

/******************************************************************************/

// Firmware generation flags for this processor
`define NRV_ARCH     "rv32imaf"
`define NRV_ABI      "ilp32f"

//`define NRV_ARCH     "rv32imac"
//`define NRV_ABI      "ilp32"

`define NRV_OPTIMIZE "-O3"
`define NRV_INTERRUPTS

// StackOverflow: Verilog-Synthesize high speed leading zero count
module CLZ #(
   parameter W_IN = 64, // must be power of 2, >= 2
   parameter W_OUT = $clog2(W_IN)	     
) (
   input wire [W_IN-1:0]   in,
   output wire [W_OUT-1:0] out
);
  generate
     if(W_IN == 2) begin
	assign out = !in[1];
     end else begin
	wire [W_OUT-2:0] half_count;
	wire [W_IN/2-1:0] lhs = in[W_IN/2 +: W_IN/2];
	wire [W_IN/2-1:0] rhs = in[0      +: W_IN/2];
	wire left_empty = ~|lhs;
	CLZ #(
	  .W_IN(W_IN/2)
        ) inner(
           .in(left_empty ? rhs : lhs),
           .out(half_count)		
	);
	assign out = {left_empty, half_count};
     end
  endgenerate
endmodule   

module FemtoRV32(
   input          clk,

   output [31:0] mem_addr,  // address bus
   output [31:0] mem_wdata, // data to be written
   output  [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input  [31:0] mem_rdata, // input lines for both data and instr
   output        mem_rstrb, // active to initiate memory read (used by IO)
   input         mem_rbusy, // asserted if memory is busy reading value
   input         mem_wbusy, // asserted if memory is busy writing value

   input         interrupt_request,

   input         reset      // set to 0 to reset the processor
);

   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

   function [49:0] flip50;
      input [49:0] x;
      flip50 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31],
		x[32], x[33], x[34], x[35], x[36], x[37], x[38], x[39], 
                x[40], x[41], x[42], x[43], x[44], x[45], x[46], x[47], 
                x[48], x[49]		
               };
   endfunction
   
   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 24;

   localparam ADDR_PAD = {(32-ADDR_WIDTH){1'b0}}; // 32-bits padding for addrs

   /***************************************************************************/
   // Instruction decoding.
   /***************************************************************************/

   // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction.
   // Reference: Table page 104 of:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

   // asserted if the destination register is a floating-point register
   wire rdIsFP = (instr[6:2] == 5'b00001)            || // FLW
	         (instr[6:4] == 3'b100  )            || // F{N}MADD,F{N}MSUB
	         (instr[6:4] == 3'b101 && (
                            (instr[31]    == 1'b0)    || // R-Type FPU
			    (instr[31:28] == 4'b1101) || // FCVT.S.W{U}
			    (instr[31:28] == 4'b1111)    // FMV.W.X 
			 )
                 );
   
   wire [4:0] rdId = instr[11:7];

   wire [2:0] funct3 = instr[14:12];
   // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
   // It is used as follows: funct3Is[val] <=> funct3 == val
   (* onehot *)
   wire [7:0] funct3Is = 8'b00000001 << instr[14:12];

   // The five imm formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   /* verilator lint_off UNUSED */ // MSBs of SBJimms not used by addr adder.
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
   /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:3] == 4'b0000 ); // rd <- mem[rs1+Iimm]  (bit 2:FLW)
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm   
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isStore   =  (instr[6:3] == 4'b0100 ); // mem[rs1+Simm] <- rs2 (bit 2:FSW)
   wire isALUreg  =  (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
   wire isLUI     =  (instr[6:2] == 5'b01101); // rd <- Uimm
   wire isBranch  =  (instr[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   wire isJALR    =  (instr[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   wire isJAL     =  (instr[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   wire isSYSTEM  =  (instr[6:2] == 5'b11100); // rd <- CSR <- rs1/uimm5
   wire isFPU     =  (instr[6:5] == 2'b10);    // all FPU instr except FLW/FSW
   
   wire isALU = isALUimm | isALUreg;

   /***************************************************************************/
   // The register file.
   /***************************************************************************/

   reg [31:0] rs1;
   reg [31:0] rs2;
   reg [31:0] registerFile [31:0]; 

   always @(posedge clk) begin
     if (writeBack && rdId != 0 && !rdIsFP) begin
          registerFile[rdId] <= writeBackData;
       end
   end

   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except divisions.
   /***************************************************************************/

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

   wire aluWr;               // ALU write strobe, starts dividing.

   // The adder is used by both arithmetic instructions and JALR.
   wire [31:0] aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   // (trick borrowed from swapforth/J1)
   wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   wire        LTU = aluMinus[32];
   wire        EQ  = (aluMinus[31:0] == 0);

   /***************************************************************************/

   // Use the same shifter both for left and right shifts by 
   // applying bit reversal

   wire [31:0] shifter_in = funct3Is[1] ? flip32(aluIn1) : aluIn1;
   
   /* verilator lint_off WIDTH */
   wire [31:0] shifter = 
               $signed({instr[30] & aluIn1[31], shifter_in}) >>> aluIn2[4:0];
   /* verilator lint_on WIDTH */

   wire [31:0] leftshift = flip32(shifter);
   
   /***************************************************************************/

   wire funcM     = instr[25];
   wire isDivide  = isALUreg & funcM & instr[14];
   wire aluBusy   = |quotient_msk; // ALU is busy if division is in progress.

   // funct3: 1->MULH, 2->MULHSU  3->MULHU
   wire isMULH   = funct3Is[1];
   wire isMULHSU = funct3Is[2];

   wire sign1 = aluIn1[31] &  isMULH;
   wire sign2 = aluIn2[31] & (isMULH | isMULHSU);

   wire signed [32:0] signed1 = {sign1, aluIn1};
   wire signed [32:0] signed2 = {sign2, aluIn2};

   reg signed [63:0]  multiply;
   
   /***************************************************************************/

   // Notes:
   // - instr[30] is 1 for SUB and 0 for ADD
   // - for SUB, need to test also instr[5] to discriminate ADDI:
   //    (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30 !)
   // - instr[30] is 1 for SRA (do sign extension) and 0 for SRL

   wire [31:0] aluOut_base =
     (funct3Is[0]  ? instr[30] & instr[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[1]  ? leftshift                                       : 32'b0) |
     (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
     (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
     (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
     (funct3Is[5]  ? shifter                                         : 32'b0) |
     (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
     (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) ;

   wire [31:0] aluOut_muldiv = 
     (  funct3Is[0]   ?  multiply[31: 0] : 32'b0) | // 0:MUL
     ( |funct3Is[3:1] ?  multiply[63:32] : 32'b0) | // 1:MULH, 2:MULHSU, 3:MULHU
     (  instr[14]     ?  div_sign ? -divResult : divResult : 32'b0) ; 
                                                 // 4:DIV, 5:DIVU, 6:REM, 7:REMU

   wire [31:0] aluOut = isALUreg & funcM ? aluOut_muldiv : aluOut_base;

   /***************************************************************************/
   // Implementation of DIV/REM instructions, highly inspired by PicoRV32

   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;

   wire divstep_do = (divisor <= {31'b0, dividend});

   wire [31:0] dividendN     = divstep_do ? dividend - divisor[31:0] : dividend;
   wire [31:0] quotientN     = divstep_do ? quotient | quotient_msk  : quotient;

   wire div_sign = ~instr[12] & (instr[13] ? aluIn1[31] : 
                                          (aluIn1[31] != aluIn2[31]) & |aluIn2);

   always @(posedge clk) begin
      multiply <= signed1 * signed2;
      if (isDivide & aluWr) begin
         dividend <=   ~instr[12] & aluIn1[31] ? -aluIn1 : aluIn1;
         divisor  <= {(~instr[12] & aluIn2[31] ? -aluIn2 : aluIn2), 31'b0};
         quotient <= 0;
         quotient_msk <= 1 << 31;
      end else begin
         dividend     <= dividendN;
         divisor      <= divisor >> 1;
         quotient     <= quotientN;
         quotient_msk <= quotient_msk >> 1;
      end
   end 
   
   reg  [31:0] divResult;
   always @(posedge clk) begin
      divResult <= instr[13] ? dividendN : quotientN;
   end

   /***************************************************************************/
   // The predicate for conditional branches.
   /***************************************************************************/

   wire predicate =
        funct3Is[0] &  EQ  | // BEQ
        funct3Is[1] & !EQ  | // BNE
        funct3Is[4] &  LT  | // BLT
        funct3Is[5] & !LT  | // BGE
        funct3Is[6] &  LTU | // BLTU
        funct3Is[7] & !LTU ; // BGEU

   /***************************************************************************/
   // The FPU 
   /***************************************************************************/

   reg [31:0] fpuOut;
   reg [31:0] fpuIntOut;
   
   reg [31:0] fp_rs1;
   reg [31:0] fp_rs2;
   reg [31:0] fp_rs3;

   reg [31:0] fp_tmp1;
   reg [31:0] fp_tmp2;
   
   // For now, flush all denormals to zero
   wire        fp_rs1_sign = fp_rs1[31];
   wire [7:0]  fp_rs1_exp  = fp_rs1[30:23];
   wire [23:0] fp_rs1_frac = fp_rs1_exp == 8'd0 ? 24'b0 : {1'b1, fp_rs1[22:0]};
   
   wire        fp_rs2_sign =  fp_rs2[31];
   wire [7:0]  fp_rs2_exp  =  fp_rs2[30:23];
   wire [23:0] fp_rs2_frac = fp_rs2_exp == 8'd0 ? 24'b0 : {1'b1, fp_rs2[22:0]};
   
   wire        fp_rs3_sign =  fp_rs3[31];
   wire [7:0]  fp_rs3_exp  =  fp_rs3[30:23];
   wire [23:0] fp_rs3_frac = fp_rs3_exp == 8'd0 ? 24'b0 : {1'b1, fp_rs3[22:0]};
   
   reg [31:0] fp_registerFile [31:0]; 

   reg 	             fp_A_sign;
   reg signed [8:0]  fp_A_exp;
   reg signed [49:0] fp_A_frac;
   
   reg 	             fp_B_sign;
   reg signed [8:0]  fp_B_exp;
   reg signed [49:0] fp_B_frac;

   // Count leading zeroes in A
   // Note: CLZ only work with power of two width
   // (hence 14'b0).
   wire [5:0] 	     fp_A_clz;
   CLZ clz({14'b0,fp_A_frac}, fp_A_clz);
   
   // Index of first bit set in A, starting from MSB of A
   wire [5:0] 	     fp_A_first_bit_set = 63-fp_A_clz;
   
   // Exponent of A once normalized.
   wire signed [8:0] fp_A_exp_norm = fp_A_exp + {3'b000,fp_A_first_bit_set} - 47;
   
   // exponent adder
   wire signed [8:0]  fp_exp_sum   = fp_B_exp + fp_A_exp;
   wire signed [8:0]  fp_exp_diff  = fp_B_exp - fp_A_exp;

   wire signed [8:0]  frcp_exp  = $signed(9'd126) + fp_A_exp - $signed({1'b0, fp_tmp2[30:23]}); // TODO: why 126 and not 127 ?
 
   wire signed [8:0]  fcvt_ftoi_shift     =  fp_rs1_exp - $signed(9'd127 + 9'd23 + 9'd6); // TODO: understand 9'd6 
   wire signed [8:0]  neg_fcvt_ftoi_shift = -fcvt_ftoi_shift;
   wire [31:0] 	      A_fcvt_ftoi_shifted =  fcvt_ftoi_shift[8] ? 
                                               (|neg_fcvt_ftoi_shift[8:5] ? 0 : (fp_A_frac[49:18] >> neg_fcvt_ftoi_shift[4:0])) : 
                                               (fp_A_frac[49:18] << fcvt_ftoi_shift[4:0]) ; // TODO: overflow

   
   wire [31:0] fp_rsqrt_doom_magic = 32'h5f3759df - {1'b0,fp_rs1[30:1]};
   
   // fraction adder
   wire signed [50:0] fp_frac_sum  = fp_B_frac + fp_A_frac;
   wire signed [50:0] fp_frac_diff = fp_B_frac - fp_A_frac;

   wire               fracA_Z = (fp_A_frac == 0);
   wire               fracB_Z = (fp_B_frac == 0);   
   
   wire 	      fracA_EQ_fracB = (fp_frac_diff == 0);
   
   wire 	      fabsA_EQ_fabsB = (fp_exp_diff == 0 && fracA_EQ_fracB);
   
   wire 	      fabsA_LT_fabsB = (!fp_exp_diff[8] && fp_exp_diff != 0) || 
                                       (fp_exp_diff == 0 && fp_frac_diff != 0 && !fp_frac_diff[50]);

   wire 	      fabsA_LE_fabsB = (!fp_exp_diff[8] && fp_exp_diff != 0) || 
                                       (fp_exp_diff == 0 && !fp_frac_diff[50]);
   
   wire 	      fabsB_LT_fabsA = fp_exp_diff[8] || (fp_exp_diff == 0 && fp_frac_diff[50]);

   wire 	      fabsB_LE_fabsA = fp_exp_diff[8] || (fp_exp_diff == 0 && (fp_frac_diff[50] || fracA_EQ_fracB));

   wire 	      A_LT_B =   fp_A_sign && !fp_B_sign ||
		                 fp_A_sign &&  fp_B_sign && fabsB_LT_fabsA ||
 		                !fp_A_sign && !fp_B_sign && fabsA_LT_fabsB ;

   wire 	      A_LE_B =   fp_A_sign && !fp_B_sign ||
		                 fp_A_sign &&  fp_B_sign && fabsB_LE_fabsA ||
 		                !fp_A_sign && !fp_B_sign && fabsA_LE_fabsB ;
   
   wire               A_EQ_B = fabsA_EQ_fabsB && (fp_A_sign == fp_B_sign);


   /** FPU micro-instructions ******************************************************************/

   localparam FPMI_READY_bit           = 0,  FPMI_READY         = 1 << FPMI_READY_bit;
   localparam FPMI_LOAD_AB_bit         = 1,  FPMI_LOAD_AB       = 1 << FPMI_LOAD_AB_bit;
   localparam FPMI_LOAD_AB_MUL_bit     = 2,  FPMI_LOAD_AB_MUL   = 1 << FPMI_LOAD_AB_MUL_bit;
   localparam FPMI_NORM_bit            = 3,  FPMI_NORM          = 1 << FPMI_NORM_bit;
   localparam FPMI_ADD_SWAP_bit        = 4,  FPMI_ADD_SWAP      = 1 << FPMI_ADD_SWAP_bit;
   localparam FPMI_ADD_SHIFT_bit       = 5,  FPMI_ADD_SHIFT     = 1 << FPMI_ADD_SHIFT_bit;
   localparam FPMI_ADD_ADD_bit         = 6,  FPMI_ADD_ADD       = 1 << FPMI_ADD_ADD_bit;
   localparam FPMI_CMP_bit             = 7,  FPMI_CMP           = 1 << FPMI_CMP_bit;

   localparam FPMI_MV_FPRS1_A_bit      =  8, FPMI_MV_FPRS1_A      = 1 << FPMI_MV_FPRS1_A_bit;
   localparam FPMI_MV_FPRS2_TMP1_bit   =  9, FPMI_MV_FPRS2_TMP1   = 1 << FPMI_MV_FPRS2_TMP1_bit;   
   localparam FPMI_MV_FPRS2_MHTMP1_bit = 10, FPMI_MV_FPRS2_MHTMP1 = 1 << FPMI_MV_FPRS2_MHTMP1_bit;
   localparam FPMI_MV_FPRS2_TMP2_bit   = 11, FPMI_MV_FPRS2_TMP2   = 1 << FPMI_MV_FPRS2_TMP2_bit;
   localparam FPMI_MV_TMP2_A_bit       = 12, FPMI_MV_TMP2_A       = 1 << FPMI_MV_TMP2_A_bit;         
   
   localparam FPMI_FRCP_PROLOG_bit     = 13, FPMI_FRCP_PROLOG   = 1 << FPMI_FRCP_PROLOG_bit;
   localparam FPMI_FRCP_ITER_bit       = 14, FPMI_FRCP_ITER     = 1 << FPMI_FRCP_ITER_bit; 
   localparam FPMI_FRCP_EPILOG_bit     = 15, FPMI_FRCP_EPILOG   = 1 << FPMI_FRCP_EPILOG_bit;
   
   localparam FPMI_FRSQRT_PROLOG_bit   = 16, FPMI_FRSQRT_PROLOG = 1 << FPMI_FRSQRT_PROLOG_bit;
   
   localparam FPMI_FP_TO_INT_bit       = 17, FPMI_FP_TO_INT     = 1 << FPMI_FP_TO_INT_bit;
   localparam FPMI_INT_TO_FP_bit       = 18, FPMI_INT_TO_FP     = 1 << FPMI_INT_TO_FP_bit;   
   localparam FPMI_OUT_bit             = 19, FPMI_OUT           = 1 << FPMI_OUT_bit;
   localparam FPMI_NB                  = 20;

   reg [6:0] 	       fpmi_PC; // current micro-instruction pointer
   reg [FPMI_NB-1:0]   fpmi_is; // 1-hot current micro-instruction

   initial fpmi_PC = 0;

   wire fpuBusy = !fpmi_is[FPMI_READY_bit];

   // micro-program ROM
   always @(*) begin
      case(fpmi_PC)
	0: fpmi_is = FPMI_READY;
	
	// FLT, FLE, FEQ
	1: fpmi_is = FPMI_LOAD_AB;
	2: fpmi_is = FPMI_CMP;

	// FADD, FSUB
	3: fpmi_is = FPMI_LOAD_AB;
	4: fpmi_is = FPMI_ADD_SWAP;
	5: fpmi_is = FPMI_ADD_SHIFT;
	6: fpmi_is = FPMI_ADD_ADD;
	7: fpmi_is = FPMI_NORM;
	8: fpmi_is = FPMI_OUT;

	// FMUL
	 9: fpmi_is = FPMI_LOAD_AB_MUL;
	10: fpmi_is = FPMI_NORM;
	11: fpmi_is = FPMI_OUT;

	// FMADD, FMSUB, FNMADD, FNMSUB
	12: fpmi_is = FPMI_LOAD_AB_MUL;
	13: fpmi_is = FPMI_ADD_SWAP;
 	14: fpmi_is = FPMI_ADD_SHIFT;
 	15: fpmi_is = FPMI_ADD_SWAP;	
	16: fpmi_is = FPMI_ADD_ADD;
	17: fpmi_is = FPMI_NORM;
	18: fpmi_is = FPMI_OUT;

	// FDIV
	19: fpmi_is = FPMI_FRCP_PROLOG;   // STEP 1: A <- -D'*32/17 + 48/17
	20: fpmi_is = FPMI_LOAD_AB_MUL;   // ---
	21: fpmi_is = FPMI_ADD_SWAP;      //    |
 	22: fpmi_is = FPMI_ADD_SHIFT;     //  FMADD
 	23: fpmi_is = FPMI_ADD_SWAP;	  //    |
	24: fpmi_is = FPMI_ADD_ADD;       //    |
	25: fpmi_is = FPMI_NORM;          // ---
	26: fpmi_is = FPMI_FRCP_ITER;     // STEP 2: A <- A * (-A*D + 2)
	27: fpmi_is = FPMI_LOAD_AB_MUL;   // ---
	28: fpmi_is = FPMI_ADD_SWAP;      //    |
 	29: fpmi_is = FPMI_ADD_SHIFT;     //  FMADD
 	30: fpmi_is = FPMI_ADD_SWAP;	  //    |
	31: fpmi_is = FPMI_ADD_ADD;       //    |
	32: fpmi_is = FPMI_NORM;          // ---
	33: fpmi_is = FPMI_MV_FPRS1_A;    // ---
	34: fpmi_is = FPMI_LOAD_AB_MUL;   //  FMUL
	35: fpmi_is = FPMI_NORM;          // ---  
	36: fpmi_is = FPMI_FRCP_ITER;     // STEP 3: A <- A * (-A*D + 2)
	37: fpmi_is = FPMI_LOAD_AB_MUL;   // ---
	38: fpmi_is = FPMI_ADD_SWAP;      //    |
 	39: fpmi_is = FPMI_ADD_SHIFT;     //  FMADD
 	40: fpmi_is = FPMI_ADD_SWAP;	  //    |
	41: fpmi_is = FPMI_ADD_ADD;       //    |
	42: fpmi_is = FPMI_NORM;          // ---
	43: fpmi_is = FPMI_MV_FPRS1_A;    // ---
	44: fpmi_is = FPMI_LOAD_AB_MUL;   //  FMUL
	45: fpmi_is = FPMI_NORM;          // ---  
	46: fpmi_is = FPMI_FRCP_EPILOG;   // STEP 4: A <- fprs1^(-1) * fprs2
	47: fpmi_is = FPMI_LOAD_AB_MUL;   //  FMUL
	48: fpmi_is = FPMI_NORM;          // ---
	49: fpmi_is = FPMI_OUT;           // 

	// FCVT.W.S, FCVT.WU.S
	50: fpmi_is = FPMI_LOAD_AB;
	51: fpmi_is = FPMI_FP_TO_INT;
	
	// FCVT.S.W, FCVT.S.WU
	52: fpmi_is = FPMI_INT_TO_FP;
	53: fpmi_is = FPMI_NORM;
	54: fpmi_is = FPMI_OUT;

	// FSQRT
	55: fpmi_is = FPMI_FRSQRT_PROLOG;
	56: fpmi_is = FPMI_LOAD_AB_MUL;   // -- FMUL
	57: fpmi_is = FPMI_NORM;          // ---'
	58: fpmi_is = FPMI_MV_FPRS1_A;
	59: fpmi_is = FPMI_MV_FPRS2_MHTMP1; 
	60: fpmi_is = FPMI_LOAD_AB_MUL;   // ---
	61: fpmi_is = FPMI_ADD_SWAP;      //    |
 	62: fpmi_is = FPMI_ADD_SHIFT;     //  FMADD
 	63: fpmi_is = FPMI_ADD_SWAP;	  //    |
	64: fpmi_is = FPMI_ADD_ADD;       //    |
	65: fpmi_is = FPMI_NORM;          // ---
	66: fpmi_is = FPMI_MV_FPRS1_A;
	67: fpmi_is = FPMI_MV_FPRS2_TMP2; 
	68: fpmi_is = FPMI_LOAD_AB_MUL;   // -- FMUL
	69: fpmi_is = FPMI_NORM;          // ---'
        70: fpmi_is = FPMI_MV_TMP2_A;
	71: fpmi_is = FPMI_MV_FPRS1_A;
	72: fpmi_is = FPMI_MV_FPRS2_TMP2;
	73: fpmi_is = FPMI_LOAD_AB_MUL;   // -- FMUL
	74: fpmi_is = FPMI_NORM;          // ---'
	75: fpmi_is = FPMI_MV_FPRS1_A;
	76: fpmi_is = FPMI_MV_FPRS2_MHTMP1; 
	77: fpmi_is = FPMI_LOAD_AB_MUL;   // ---
	78: fpmi_is = FPMI_ADD_SWAP;      //    |
 	79: fpmi_is = FPMI_ADD_SHIFT;     //  FMADD
 	80: fpmi_is = FPMI_ADD_SWAP;	  //    |
	81: fpmi_is = FPMI_ADD_ADD;       //    |
	82: fpmi_is = FPMI_NORM;          // ---
	83: fpmi_is = FPMI_MV_FPRS1_A;
	84: fpmi_is = FPMI_MV_FPRS2_TMP2; 
	85: fpmi_is = FPMI_LOAD_AB_MUL;   // -- FMUL
	86: fpmi_is = FPMI_NORM;          // ---'
	87: fpmi_is = FPMI_MV_FPRS1_A;
	88: fpmi_is = FPMI_MV_FPRS2_TMP1;
	89: fpmi_is = FPMI_LOAD_AB_MUL;   // -- FMUL
	90: fpmi_is = FPMI_NORM;          // ---'
	91: fpmi_is = FPMI_OUT;    
	
	default: fpmi_is = FPMI_READY;
      endcase
   end
   
   // micro-programs
   localparam FPMPROG_CMP        = 1;
   localparam FPMPROG_ADD        = 3;
   localparam FPMPROG_MUL        = 9;
   localparam FPMPROG_MADD       = 12;
   localparam FPMPROG_DIV        = 19;
   localparam FPMPROG_FP_TO_INT  = 50;
   localparam FPMPROG_INT_TO_FP  = 52;         
   localparam FPMPROG_SQRT       = 55;
   
   /*******************************************************/


   always @(posedge clk) begin

      
      if(state[WAIT_INSTR_bit] && !mem_rbusy) begin
	 // TODO: decompression / raw_instr
	 fp_rs1 <= fp_registerFile[raw_instr[19:15]];
	 fp_rs2 <= fp_registerFile[raw_instr[24:20]];
	 fp_rs3 <= fp_registerFile[raw_instr[31:27]]; // TODO: read from other state ?

      end else if(state[EXECUTE_bit] & isFPU) begin

	 (* parallel_case *)
	 case(1'b1)
	   // Single-cycle instructions
	   isFSGNJ  : fpuOut    <= {            fp_rs2[31], fp_rs1[30:0]};
	   isFSGNJN : fpuOut    <= {           !fp_rs2[31], fp_rs1[30:0]};	   
	   isFSGNJX : fpuOut    <= { fp_rs1[31]^fp_rs2[31], fp_rs1[30:0]};	   
           isFMVXW  : fpuIntOut <= fp_rs1;
	   isFMVWX  : fpuOut    <= rs1;	   
	   
	   // Micro-programmed instructions
	   isFLT | isFLE | isFEQ                   : fpmi_PC <= FPMPROG_CMP;
	   isFADD  | isFSUB                        : fpmi_PC <= FPMPROG_ADD;
	   isFMUL                                  : fpmi_PC <= FPMPROG_MUL;
	   isFMADD | isFMSUB | isFNMADD | isFNMSUB : fpmi_PC <= FPMPROG_MADD;
	   isFDIV                                  : fpmi_PC <= FPMPROG_DIV;
	   isFSQRT                                 : fpmi_PC <= FPMPROG_SQRT;
	   
	   isFCVTWS | isFCVTWUS                    : fpmi_PC <= FPMPROG_FP_TO_INT;
	   isFCVTSW | isFCVTSWU                    : fpmi_PC <= FPMPROG_INT_TO_FP; 
	 endcase 
	 
      end else if(state[WAIT_ALU_OR_MEM_bit] | state[WAIT_ALU_OR_MEM_SKIP_bit]) begin
	 
	 fpmi_PC <= fpmi_PC+1;

	 case(1'b1)
	   fpmi_is[FPMI_READY_bit]: fpmi_PC <= 0;
	   
	   fpmi_is[FPMI_LOAD_AB_bit]: begin
	      fp_A_sign <= fp_rs1_sign;
	      fp_A_frac <= {2'b0, fp_rs1_frac, 24'd0};
	      fp_A_exp  <= {1'b0, fp_rs1_exp}; 
	      fp_B_sign <= fp_rs2_sign ^ isFSUB;
	      fp_B_frac <= {2'b0, fp_rs2_frac, 24'd0};
	      fp_B_exp  <= {1'b0, fp_rs2_exp}; 
	   end
	   
	   fpmi_is[FPMI_LOAD_AB_MUL_bit]: begin
	      fp_A_sign <= fp_rs1_sign ^ fp_rs2_sign ^ (isFNMSUB | isFNMADD);
	      fp_A_frac <= {26'b0,fp_rs1_frac} * {26'b0,fp_rs2_frac};
	      fp_A_exp  <= fp_rs1_exp + fp_rs2_exp - 126; // TODO: why 126 rather than 127 ? // TODO: check underflow 
	      fp_B_sign <= fp_rs3_sign ^ (isFMSUB | isFNMADD);
	      fp_B_frac <= {2'b0, fp_rs3_frac, 24'd0};
	      fp_B_exp  <= {1'b0, fp_rs3_exp}; 
	   end
	   
	   fpmi_is[FPMI_NORM_bit]: begin
	      if(fp_A_exp_norm <= 0 || fracA_Z) begin
		 fp_A_frac <= 0;
		 fp_A_exp <= 0;
	      end else begin
		 
		 /*
		 if(fp_A_first_bit_set >= 23) begin
		    fp_A_frac <= fp_A_frac >> (fp_A_first_bit_set - 23);
		 end else begin
		    fp_A_frac <= fp_A_frac << (23-fp_A_first_bit_set);
		 end
		 */
		 
		 if(fp_A_first_bit_set >= 47) begin
		    fp_A_frac <= fp_A_frac >> (fp_A_first_bit_set-47);
		 end else begin
		    fp_A_frac <= fp_A_frac << (47-fp_A_first_bit_set);
		 end
		 
		 fp_A_exp  <= fp_A_exp_norm;
	      end
	   end

	   fpmi_is[FPMI_ADD_SWAP_bit]: begin
	      if(
		  fracA_Z ||  (fp_exp_diff[8] && !fracB_Z) || 
		 (fp_A_exp == fp_B_exp && fp_frac_diff[50]) 
	      ) begin 
		 fp_A_frac <= fp_B_frac; fp_B_frac <= fp_A_frac;
		 fp_A_exp  <= fp_B_exp;  fp_B_exp  <= fp_A_exp;
		 fp_A_sign <= fp_B_sign; fp_B_sign <= fp_A_sign;
	      end
	   end

	   fpmi_is[FPMI_ADD_SHIFT_bit]: begin
	      if(!fracA_Z && !fracB_Z) begin
		 if(fp_exp_diff > 47) begin
		    fp_A_frac <= 0;
		 end else begin
		    fp_A_frac <= fp_A_frac >> fp_exp_diff; 
		 end
		 fp_A_exp <= fp_B_exp;
	      end
	   end

	   fpmi_is[FPMI_ADD_ADD_bit]: begin
	      if(!fracB_Z) begin	      
		 fp_A_frac <= (fp_A_sign ^ fp_B_sign) ? fp_frac_diff[49:0] : fp_frac_sum[49:0] ;
		 fp_A_sign <= fp_B_sign;
	      end
	   end

	   fpmi_is[FPMI_CMP_bit]: begin
	      fpuIntOut <= {31'b0, 
			    isFLT && A_LT_B ||
			    isFLE && A_LE_B ||
			    isFEQ && A_EQ_B
			    };
	      fpmi_PC <= 0;
	   end

	   fpmi_is[FPMI_MV_FPRS1_A_bit]     : fp_rs1 <= {fp_A_sign, fp_A_exp[7:0], fp_A_frac[46:24]}; 
	   fpmi_is[FPMI_MV_FPRS2_TMP1_bit]:   fp_rs2 <= fp_tmp1;
	   fpmi_is[FPMI_MV_FPRS2_MHTMP1_bit]: fp_rs2 <= {1'b1, fp_tmp1[30:23]-8'd1, fp_tmp1[22:0]}; // fp_rs2 <= -fp_tmp1 / 2.0
	   fpmi_is[FPMI_MV_FPRS2_TMP2_bit]  : fp_rs2 <= fp_tmp2;
	   fpmi_is[FPMI_MV_TMP2_A_bit]      : fp_tmp2 <= {fp_A_sign, fp_A_exp[7:0], fp_A_frac[46:24]}; 
	   
	   fpmi_is[FPMI_FRCP_PROLOG_bit]: begin
	      fp_tmp1 <= fp_rs1;
	      fp_tmp2 <= fp_rs2;
	      fp_rs1  <= {1'b1, 8'd126, fp_rs2_frac[22:0]}; // D'
	      fp_rs2  <= 32'h3FF0F0F1; // 32/17
	      fp_rs3  <= 32'h4034B4B5; // 48/17
	   end
	   
	   fpmi_is[FPMI_FRCP_ITER_bit]: begin
	      fp_rs1  <= {1'b1, 8'd126, fp_tmp2[22:0]}; // -D'
	      fp_rs2  <= {fp_A_sign, fp_A_exp[7:0], fp_A_frac[46:24]}; // A
	      fp_rs3  <= 32'h40000000; // 2.0
	   end
	      
	   fpmi_is[FPMI_FRCP_EPILOG_bit]: begin
	      fp_rs1 <= {fp_tmp2[31], frcp_exp[7:0], fp_A_frac[46:24]};
	      fp_rs2 <= fp_tmp1;
	   end

	   fpmi_is[FPMI_FRSQRT_PROLOG_bit]: begin
	      fp_tmp1 <= fp_rs1;
	      fp_tmp2 <= fp_rsqrt_doom_magic;
	      fp_rs1  <= fp_rsqrt_doom_magic;
	      fp_rs2  <= fp_rsqrt_doom_magic;
	      fp_rs3  <= 32'h3fc00000; // 1.5
	   end
	   
	   fpmi_is[FPMI_FP_TO_INT_bit]: begin
	      // TODO: check overflow
	      fpuIntOut <= isFCVTWUS | !fp_A_sign ? A_fcvt_ftoi_shifted : -$signed(A_fcvt_ftoi_shifted);
	   end

	   fpmi_is[FPMI_INT_TO_FP_bit]: begin
	      // TODO: rounding
	      fp_A_frac <= isFCVTSWU | !rs1[31] ? {rs1, 18'd0} : {-$signed(rs1), 18'd0}; 
	      fp_A_sign <= isFCVTSW & rs1[31];
	      fp_A_exp  <= 156; // TODO: understand, why 156 ?
	   end
	   
	   fpmi_is[FPMI_OUT_bit]: begin
	      // TODO: wire fpuOut directly on A register and remove FP_OUT state
	      fpuOut <= {fp_A_sign, fp_A_exp[7:0], fp_A_frac[46:24]};
	      fpmi_PC <= 0;
	   end
	 endcase
      end 

      if (writeBack && rdIsFP) begin
	 fp_registerFile[rdId] <= isLoad ? mem_rdata : fpuOut;
      end
      
   end
   
   // RV32F instruction decoder
   // See table p133 (RV32G instruction listings)
   // Notes:
   //  - FLW/FSW handled by LOAD/STORE (instr[2] set if FLW/FSW)
   //  - For all other F instructions, instr[6:5] == 2'b10
   //  - FMADD/FSUB/FNMADD/FNSUB: instr[4] = 1'b0
   //  - For all remaining F instructions, instr[4] = 1'b1
   //  - FMV.X.W and FCLASS have same funct7 (7'b1110000),
   //      (discriminated by instr[12])
   
   wire isFMADD   = (instr[4:2] == 3'b000); // rd <-  rs1*rs2+rs3
   wire isFMSUB   = (instr[4:2] == 3'b001); // rd <-  rs1*rs2-rs3
   wire isFNMSUB  = (instr[4:2] == 3'b010); // rd <- -rs1*rs2+rs3 (yes, *plus  rs3* !!!)
   wire isFNMADD  = (instr[4:2] == 3'b011); // rd <- -rs1*rs2-rs3 (yes, *minus rs3* !!!)     

   wire isFADD    = (instr[4] && (instr[31:27] == 5'b00000));
   wire isFSUB    = (instr[4] && (instr[31:27] == 5'b00001));
   wire isFMUL    = (instr[4] && (instr[31:27] == 5'b00010));
   wire isFDIV    = (instr[4] && (instr[31:27] == 5'b00011));
   wire isFSQRT   = (instr[4] && (instr[31:27] == 5'b01011));   

   wire isFSGNJ   = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b00));
   wire isFSGNJN  = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b01));      
   wire isFSGNJX  = (instr[4] && (instr[31:27] == 5'b00100) && (instr[13:12] == 2'b10));   

   wire isFMIN    = (instr[4] && (instr[31:27] == 5'b00101) && !instr[12]);
   wire isFMAX    = (instr[4] && (instr[31:27] == 5'b00101) &&  instr[12]);      

   wire isFEQ     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b10));
   wire isFLT     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b01));
   wire isFLE     = (instr[4] && (instr[31:27] == 5'b10100) && (instr[13:12] == 2'b00));                        
   
   wire isFCLASS  = (instr[4] && (instr[31:27] == 5'b11100) &&  instr[12]);               
   
   wire isFCVTWS  = (instr[4] && (instr[31:27] == 5'b11000) && !instr[20]);
   wire isFCVTWUS = (instr[4] && (instr[31:27] == 5'b11000) &&  instr[20]);

   wire isFCVTSW  = (instr[4] && (instr[31:27] == 5'b11010) && !instr[20]);
   wire isFCVTSWU = (instr[4] && (instr[31:27] == 5'b11010) &&  instr[20]);

   wire isFMVXW   = (instr[4] && (instr[31:27] == 5'b11100) && !instr[12]);
   wire isFMVWX   = (instr[4] && (instr[31:27] == 5'b11110));

`ifdef VERILATOR   
   always @(posedge clk) begin
      if(isFPU && state[EXECUTE_bit]) begin
	 case(1'b1)
	     // isFMADD  : fpuOut <= $c32("FMADD(",fp_rs1,",",fp_rs2,",",fp_rs3,")");
	     // isFMSUB  : fpuOut <= $c32("FMSUB(",fp_rs1,",",fp_rs2,",",fp_rs3,")");
	     // isFNMSUB : fpuOut <= $c32("FNMSUB(",fp_rs1,",",fp_rs2,",",fp_rs3,")");
	     // isFNMADD : fpuOut <= $c32("FNMADD(",fp_rs1,",",fp_rs2,",",fp_rs3,")");
	   
	     // isFMUL   : fpuOut <= $c32("FMUL(",fp_rs1,",",fp_rs2,")");
	     // isFADD   : fpuOut <= $c32("FADD(",fp_rs1,",",fp_rs2,")");
	     // isFSUB   : fpuOut <= $c32("FSUB(",fp_rs1,",",fp_rs2,")");
	   
	     // isFDIV   : fpuOut <= $c32("FDIV(",fp_rs1,",",fp_rs2,")");
	     // isFSQRT  : fpuOut <= $c32("FSQRT(",fp_rs1,")");

	   
	     //isFSGNJ  : fpuOut <= $c32("FSGNJ(",fp_rs1,",",fp_rs2,")");
	     //isFSGNJN : fpuOut <= $c32("FSGNJN(",fp_rs1,",",fp_rs2,")");
	     //isFSGNJX : fpuOut <= $c32("FSGNJX(",fp_rs1,",",fp_rs2,")");

	     // isFSGNJ  : fpuOut <= {            fp_rs2[31], fp_rs1[30:0]};
	     // isFSGNJN : fpuOut <= {           !fp_rs2[31], fp_rs1[30:0]};	   
	     // isFSGNJX : fpuOut <= { fp_rs1[31]^fp_rs2[31], fp_rs1[30:0]};	   
	   
	     isFMIN   : fpuOut <= $c32("FMIN(",fp_rs1,",",fp_rs2,")");
	     isFMAX   : fpuOut <= $c32("FMAX(",fp_rs1,",",fp_rs2,")");
	   
	     // isFEQ    : fpuIntOut <= $c32("FEQ(",fp_rs1,",",fp_rs2,")");
	     // isFLE    : fpuIntOut <= $c32("FLE(",fp_rs1,",",fp_rs2,")");
	     // isFLT    : fpuIntOut <= $c32("FLT(",fp_rs1,",",fp_rs2,")");
	   
	     isFCLASS : fpuIntOut <= $c32("FCLASS(",fp_rs1,")") ;
	   
	     // isFCVTWS : fpuIntOut <= $c32("FCVTWS(",fp_rs1,")");
	     // isFCVTWUS: fpuIntOut <= $c32("FCVTWUS(",fp_rs1,")");
	   
	     // isFCVTSW : fpuOut <= $c32("FCVTSW(",rs1,")");
	     // isFCVTSWU: fpuOut <= $c32("FCVTSWU(",rs1,")");
	     
             // isFMVXW:   fpuIntOut <= fp_rs1;
	     // isFMVWX:   fpuOut <= rs1;	   
         endcase		     
      end		     
   end


   // This block for verifying the result in the simulation.
   reg [31:0] dummy;
   reg [31:0] fp_rs1_bkp;
   reg [31:0] fp_rs2_bkp;
   reg [31:0] fp_rs3_bkp;   
   
   always @(posedge clk) begin
      if(isFPU && state[EXECUTE_bit]) begin
	 fp_rs1_bkp <= fp_rs1;
	 fp_rs2_bkp <= fp_rs2;
	 fp_rs3_bkp <= fp_rs3;
      end
      
      if(isFPU && (state[WAIT_ALU_OR_MEM_bit] | state[WAIT_ALU_OR_MEM_SKIP_bit]) & fpmi_PC == 0) begin
	 case(1'b1)
	   isFMUL    : dummy <= $c32("CHECK_FMUL(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");
	   isFADD    : dummy <= $c32("CHECK_FADD(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");
	   isFSUB    : dummy <= $c32("CHECK_FSUB(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");
	   
	   // my FFIV and FSQRT are not IEEE754 compliant ! (check commented-out for now)
	   // isFDIV    : dummy <= $c32("CHECK_FDIV(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");
	   // isFSQRT   : dummy <= $c32("CHECK_FSQRT(",fpuOut,",",fp_rs1_bkp,")");	   

	   isFMADD   : dummy <= $c32("CHECK_FMADD(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,",",fp_rs3_bkp,")");
	   isFMSUB   : dummy <= $c32("CHECK_FMSUB(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,",",fp_rs3_bkp,")");
	   isFNMSUB  : dummy <= $c32("CHECK_FNMSUB(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,",",fp_rs3_bkp,")");
	   isFNMADD  : dummy <= $c32("CHECK_FNMADD(",fpuOut,",",fp_rs1_bkp,",",fp_rs2_bkp,",",fp_rs3_bkp,")");

	   isFEQ     : dummy <= $c32("CHECK_FEQ(",fpuIntOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");
	   isFLT     : dummy <= $c32("CHECK_FLT(",fpuIntOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");	   
	   isFLE     : dummy <= $c32("CHECK_FLE(",fpuIntOut,",",fp_rs1_bkp,",",fp_rs2_bkp,")");

	   isFCVTWS  : dummy <= $c32("CHECK_FCVTWS(",fpuIntOut,",",fp_rs1_bkp,")");
	   isFCVTWUS : dummy <= $c32("CHECK_FCVTWUS(",fpuIntOut,",",fp_rs1_bkp,")");

	   isFCVTSW  : dummy <= $c32("CHECK_FCVTSW(",fpuOut,",",rs1,")");
	   isFCVTSWU : dummy <= $c32("CHECK_FCVTSWU(",fpuOut,",",rs1,")");	   
	   
	 endcase
      end
   end 
   
`endif
   
   /***************************************************************************/
   // Program counter and branch target computation.
   /***************************************************************************/

   reg  [ADDR_WIDTH-1:0] PC; // The program counter.
   reg  [31:2] instr;        // Latched instruction. Note that bits 0 and 1 are
                             // ignored (not used in RV32I base instr set).

   wire [ADDR_WIDTH-1:0] PCplus2 = PC + 2;
   wire [ADDR_WIDTH-1:0] PCplus4 = PC + 4;
   wire [ADDR_WIDTH-1:0] PCinc   = long_instr ? PCplus4 : PCplus2;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   // Equivalent to PCplusImm = PC + (isJAL ? Jimm : isAUIPC ? Uimm : Bimm)
   wire [ADDR_WIDTH-1:0] PCplusImm = PC + ( instr[3] ? Jimm[ADDR_WIDTH-1:0] :
                                            instr[4] ? Uimm[ADDR_WIDTH-1:0] :
                                                       Bimm[ADDR_WIDTH-1:0] );

   // A separate adder to compute the destination of load/store.
   // testing instr[5] is equivalent to testing isStore in this context.
   wire [ADDR_WIDTH-1:0] loadstore_addr = rs1[ADDR_WIDTH-1:0] +
                   (instr[5] ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

   assign mem_addr = {ADDR_PAD,
                       state[WAIT_INSTR_bit] | state[FETCH_INSTR_bit] ?
                       fetch_second_half ? {PCplus4[ADDR_WIDTH-1:2], 2'b00}
                                         : {PC     [ADDR_WIDTH-1:2], 2'b00}
                       : loadstore_addr
                     };

   /***************************************************************************/
   // Interrupt logic, CSR registers and opcodes.
   /***************************************************************************/

   // Remember interrupt requests as they are not checked for every cycle
   reg  interrupt_request_sticky;
   
   // Interrupt enable and lock logic
   wire interrupt = interrupt_request_sticky & mstatus & ~mcause;

   // Processor accepts interrupts in EXECUTE state.   
   wire interrupt_accepted = interrupt & state[EXECUTE_bit];        

   // If current interrupt is accepted, there already might be the next one,
   //  which should not be missed:
   always @(posedge clk) begin
     interrupt_request_sticky <= 
         interrupt_request | (interrupt_request_sticky & ~interrupt_accepted);
   end

   // Decoder for mret opcode
   wire interrupt_return = isSYSTEM & funct3Is[0]; // & (instr[31:20]==12'h302);

   // CSRs:
   reg  [ADDR_WIDTH-1:0] mepc;    // The saved program counter.
   reg  [ADDR_WIDTH-1:0] mtvec;   // The address of the interrupt handler.
   reg                   mstatus; // Interrupt enable
   reg                   mcause;  // Interrupt cause (and lock)
   reg  [63:0]           cycles;  // Cycle counter

   always @(posedge clk) cycles <= cycles + 1;

   wire sel_mstatus = (instr[31:20] == 12'h300);
   wire sel_mtvec   = (instr[31:20] == 12'h305);
   wire sel_mepc    = (instr[31:20] == 12'h341);
   wire sel_mcause  = (instr[31:20] == 12'h342);
   wire sel_cycles  = (instr[31:20] == 12'hC00);
   wire sel_cyclesh = (instr[31:20] == 12'hC80);

   // Read CSRs
   wire [31:0] CSR_read =
     (sel_mstatus ?    {28'b0, mstatus, 3'b0}  : 32'b0) |
     (sel_mtvec   ? {ADDR_PAD, mtvec}          : 32'b0) |
     (sel_mepc    ? {ADDR_PAD, mepc }          : 32'b0) |
     (sel_mcause  ?            {mcause, 31'b0} : 32'b0) |
     (sel_cycles  ?            cycles[31:0]    : 32'b0) |
     (sel_cyclesh ?            cycles[63:32]   : 32'b0) ;


   // Write CSRs: 5 bit unsigned immediate or content of RS1
   wire [31:0] CSR_modifier = instr[14] ? {27'd0, instr[19:15]} : rs1; 

   wire [31:0] CSR_write = (instr[13:12] == 2'b10) ? CSR_modifier | CSR_read  :
                           (instr[13:12] == 2'b11) ? ~CSR_modifier & CSR_read :
                        /* (instr[13:12] == 2'b01) ? */  CSR_modifier ;

   always @(posedge clk) begin
      if(!reset) begin
	 mstatus <= 0;
      end else begin
	 // Execute a CSR opcode
	 if (isSYSTEM & (instr[14:12] != 0) & state[EXECUTE_bit]) begin
	    if (sel_mstatus) mstatus <= CSR_write[3];
	    if (sel_mtvec  ) mtvec   <= CSR_write[ADDR_WIDTH-1:0];
	 end
      end
   end

   /***************************************************************************/
   // The value written back to the register file.
   /***************************************************************************/

   wire [31:0] writeBackData  =
      (isSYSTEM            ? CSR_read             : 32'b0) |  // SYSTEM
      (isLUI               ? Uimm                 : 32'b0) |  // LUI
      (isALU               ? aluOut               : 32'b0) |  // ALUreg, ALUimm
      (isFPU               ? fpuIntOut            : 32'b0) |  // FPU
      (isAUIPC             ? {ADDR_PAD,PCplusImm} : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? {ADDR_PAD,PCinc    } : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data            : 32'b0);   // Load

   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary. For this
   // reason, we need some circuitry that does unaligned halfword
   // and byte load/store, based on:
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   // TODO: support unaligned accesses for FLW and FSW 
   
   // instr[2] is set for FLW and FSW. instr[13:12] = func3[1:0]
   wire mem_byteAccess     = !instr[2] && (instr[13:12] == 2'b00); 
   wire mem_halfwordAccess = !instr[2] && (instr[13:12] == 2'b01); 

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion

   wire LOAD_sign =
        !instr[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   wire [31:0] LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   wire [15:0] LOAD_halfword =
               loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   wire  [7:0] LOAD_byte =
               loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // STORE

   wire [31:0] i_mem_wdata;
   assign i_mem_wdata[ 7: 0] = rs2[7:0];
   assign i_mem_wdata[15: 8] = loadstore_addr[0] ? rs2[7:0]  : rs2[15: 8];
   assign i_mem_wdata[23:16] = loadstore_addr[1] ? rs2[7:0]  : rs2[23:16];
   assign i_mem_wdata[31:24] = loadstore_addr[0] ? rs2[7:0]  :
                               loadstore_addr[1] ? rs2[15:8] : rs2[31:24];

   assign mem_wdata = instr[2] ? fp_rs2 : i_mem_wdata;
   
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

   /***************************************************************************/
   // Unaligned fetch mechanism and compressed opcode handling
   /***************************************************************************/

   reg [ADDR_WIDTH-1:2] cached_addr;
   reg           [31:0] cached_data;

   wire current_cache_hit = cached_addr == PC     [ADDR_WIDTH-1:2];
   wire    next_cache_hit = cached_addr == PC_new [ADDR_WIDTH-1:2];

   wire current_unaligned_long = &cached_mem [17:16] & PC    [1];
   wire    next_unaligned_long = &cached_data[17:16] & PC_new[1];

   reg fetch_second_half;
   reg long_instr;

   wire [31:0] cached_mem   = current_cache_hit ? cached_data : mem_rdata;
   wire [31:0] raw_instr = PC[1] ? {mem_rdata[15:0], cached_mem[31:16]} 
                                    : cached_mem;
   wire [31:0] decompressed;

   decompressor _decomp ( .c(raw_instr[15:0]), .d(decompressed) );

   /*************************************************************************/
   // And, last but not least, the state machine.
   /*************************************************************************/

   localparam FETCH_INSTR_bit          = 0;
   localparam WAIT_INSTR_bit           = 1;
   localparam DECOMPRESS_bit           = 2;
   localparam DECOMPRESS_REGS_bit      = 3;   
   localparam EXECUTE_bit              = 4;
   localparam WAIT_ALU_OR_MEM_bit      = 5;
   localparam WAIT_ALU_OR_MEM_SKIP_bit = 6;

   localparam NB_STATES                = 7;

   localparam FETCH_INSTR          = 1 << FETCH_INSTR_bit;
   localparam WAIT_INSTR           = 1 << WAIT_INSTR_bit;
   localparam DECOMPRESS           = 1 << DECOMPRESS_bit;
   localparam DECOMPRESS_REGS      = 1 << DECOMPRESS_REGS_bit;   
   localparam EXECUTE              = 1 << EXECUTE_bit;
   localparam WAIT_ALU_OR_MEM      = 1 << WAIT_ALU_OR_MEM_bit;
   localparam WAIT_ALU_OR_MEM_SKIP = 1 << WAIT_ALU_OR_MEM_SKIP_bit;

   (* onehot *)
   reg [NB_STATES-1:0] state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.

   // register write-back enable.
   wire writeBack = ~(isBranch | isStore ) & (
            state[EXECUTE_bit] | 
	    state[WAIT_ALU_OR_MEM_bit] | 
            state[WAIT_ALU_OR_MEM_SKIP_bit]
   );

   // The memory-read signal.
   assign mem_rstrb = state[EXECUTE_bit] & isLoad | state[FETCH_INSTR_bit];

   // The mask for memory-write.
   assign mem_wmask = {4{state[EXECUTE_bit] & isStore}} & STORE_wmask;

   // aluWr starts computation (divide) in the ALU.
   assign aluWr = state[EXECUTE_bit] & isALU;

   wire jumpToPCplusImm = isJAL | (isBranch & predicate);

   wire needToWait = isLoad | isStore | (isALUreg & funcM) | isFPU;  

   wire [ADDR_WIDTH-1:0] PC_new = 
           isJALR           ? {aluPlus[ADDR_WIDTH-1:1],1'b0} :
           jumpToPCplusImm  ? PCplusImm :
           interrupt_return ? mepc :
                              PCinc;

   always @(posedge clk) begin
      if(!reset) begin
         state             <= WAIT_ALU_OR_MEM;     //Just waiting for !mem_wbusy
         PC                <= RESET_ADDR[ADDR_WIDTH-1:0];
         mcause            <= 0;
         cached_addr       <= {ADDR_WIDTH-2{1'b1}};//Needs to be an invalid addr
         fetch_second_half <= 0;
      end else begin

	 // See note [1] at the end of this file.
	 (* parallel_case *)
	 case(1'b1)

           state[WAIT_INSTR_bit]: begin
              if(!mem_rbusy) begin // may be high when executing from SPI flash
		 // Update cache
		 if (~current_cache_hit | fetch_second_half) begin
                    cached_addr <= mem_addr[ADDR_WIDTH-1:2];
                    cached_data <= mem_rdata;
		 end;

		 // Decode instruction
		 // Note: fp_rs1 and fp_rs2 are accessed at the same
		 // time (see "The FPU" section).
		 rs1    <= registerFile[raw_instr[19:15]];
		 rs2    <= registerFile[raw_instr[24:20]];
		 instr      <= raw_instr[31:2];
		 long_instr <= &raw_instr[1:0];

		 // Long opcode, unaligned, first part fetched, 
		 // happens in non-linear code
		 if (current_unaligned_long & ~fetch_second_half) begin
                    fetch_second_half <= 1;
                    state <= FETCH_INSTR;
		 end else begin
                    fetch_second_half <= 0;
                    state <= &raw_instr[1:0] ? EXECUTE : DECOMPRESS;
		 end
              end
           end

           state[DECOMPRESS_bit]: begin
	      instr <= decompressed[31:2]; // NOTE: decompressor is a bottleneck
	      state <= DECOMPRESS_REGS;
	   end

           state[DECOMPRESS_REGS_bit]: begin
	      rs1   <= registerFile[instr[19:15]];
	      rs2   <= registerFile[instr[24:20]];
	      state <= EXECUTE;
	   end
	   
           state[EXECUTE_bit]: begin
	      // $display("PC=%x instr=%b",PC,instr);
              if (interrupt) begin
		 PC     <= mtvec;
		 mepc   <= PC_new;
		 mcause <= 1;
		 state  <= needToWait ? WAIT_ALU_OR_MEM : FETCH_INSTR;
              end else begin

		 if((isLoad | isStore) && instr[2] && |loadstore_addr[1:0]) begin
		    $display("PC=%x UNALIGNED FLW/FSW",PC);
		 end
		 
		 PC <= PC_new;
		 if (interrupt_return) mcause <= 0;

		 state <= next_cache_hit & ~next_unaligned_long
  		        ? (needToWait ? WAIT_ALU_OR_MEM_SKIP : WAIT_INSTR)
			: (needToWait ? WAIT_ALU_OR_MEM      : FETCH_INSTR);

		 fetch_second_half <= next_cache_hit & next_unaligned_long;
              end
           end

           state[WAIT_ALU_OR_MEM_bit]: begin
              if(!aluBusy & !fpuBusy & !mem_rbusy & !mem_wbusy) begin
                 state <= FETCH_INSTR;
	      end
           end

           state[WAIT_ALU_OR_MEM_SKIP_bit]: begin
              if(!aluBusy & !fpuBusy & !mem_rbusy & !mem_wbusy) begin
                 state <= WAIT_INSTR;
	      end
           end

           default: begin // FETCH_INSTR
              state <= WAIT_INSTR;
           end
	 endcase 
      end
   end

`ifdef BENCH
   initial begin
      cycles = 0;
      registerFile[0] = 0;
   end
`endif

endmodule

/*****************************************************************************/

// if c[15:0] is a compressed instrution, decompresses it in d
// else copies c to d
// TODO: decompress RV32F instructions

module decompressor(
   input  wire [15:0] c,
   output reg  [31:0] d
);

   // Notes: * replaced illegal, unknown, x0, x1, x2 with
   //   'localparam' instead of 'wire='
   //        * could split decoding into multiple cycles
   //   if decompressor is a bottleneck
   
   // How to handle illegal and unknown opcodes
   localparam illegal = 32'h0;
   localparam unknown = 32'h0;

   // Register decoder

   wire [4:0] rcl = {2'b01, c[4:2]}; // Register compressed low
   wire [4:0] rch = {2'b01, c[9:7]}; // Register compressed high

   wire [4:0] rwl  = c[ 6:2];  // Register wide low
   wire [4:0] rwh  = c[11:7];  // Register wide high

   localparam x0 = 5'b00000;
   localparam x1 = 5'b00001;
   localparam x2 = 5'b00010;   
   
   // Immediate decoder

   wire  [4:0]    shiftImm = c[6:2];

   wire [11:0] addi4spnImm = {2'b00, c[10:7], c[12:11], c[5], c[6], 2'b00};
   wire [11:0]     lwswImm = {5'b00000, c[5], c[12:10] , c[6], 2'b00};
   wire [11:0]     lwspImm = {4'b0000, c[3:2], c[12], c[6:4], 2'b00};
   wire [11:0]     swspImm = {4'b0000, c[8:7], c[12:9], 2'b00};

   wire [11:0] addi16spImm = {{ 3{c[12]}}, c[4:3], c[5], c[2], c[6], 4'b0000};
   wire [11:0]      addImm = {{ 7{c[12]}}, c[6:2]};

   /* verilator lint_off UNUSED */
   wire [12:0]        bImm = {{ 5{c[12]}}, c[6:5], c[2], c[11:10], c[4:3], 1'b0};
   wire [20:0]      jalImm = {{10{c[12]}}, c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], 1'b0};
   wire [31:0]      luiImm = {{15{c[12]}}, c[6:2], 12'b000000000000};
   /* verilator lint_on UNUSED */

   always @*
   casez (c[15:0])
                                                     // imm / funct7   +   rs2  rs1     fn3                   rd    opcode
//    16'b???___????????_???_11 : d =                                                                            c  ; // Long opcode, no need to decompress

/* verilator lint_off CASEOVERLAP */
     
      16'b000___00000000_000_00 : d =                                                                       illegal ; // c.illegal   -->  illegal
      16'b000___????????_???_00 : d = {      addi4spnImm,             x2, 3'b000,                 rcl, 7'b00100_11} ; // c.addi4spn  -->  addi rd', x2, nzuimm[9:2]
/* verilator lint_on CASEOVERLAP */
     
      16'b010_???_???_??_???_00 : d = {          lwswImm,            rch, 3'b010,                 rcl, 7'b00000_11} ; // c.lw        -->  lw   rd', offset[6:2](rs1')
      16'b110_???_???_??_???_00 : d = {    lwswImm[11:5],       rcl, rch, 3'b010,        lwswImm[4:0], 7'b01000_11} ; // c.sw        -->  sw   rs2', offset[6:2](rs1')

      16'b000_???_???_??_???_01 : d = {           addImm,            rwh, 3'b000,                 rwh, 7'b00100_11} ; // c.addi      -->  addi rd, rd, nzimm[5:0]
      16'b001____???????????_01 : d = {     jalImm[20], jalImm[10:1], jalImm[11], jalImm[19:12],   x1, 7'b11011_11} ; // c.jal       -->  jal  x1, offset[11:1]
      16'b010__?_?????_?????_01 : d = {           addImm,             x0, 3'b000,                 rwh, 7'b00100_11} ; // c.li        -->  addi rd, x0, imm[5:0]
      16'b011__?_00010_?????_01 : d = {      addi16spImm,            rwh, 3'b000,                 rwh, 7'b00100_11} ; // c.addi16sp  -->  addi x2, x2, nzimm[9:4]
      16'b011__?_?????_?????_01 : d = {    luiImm[31:12],                                         rwh, 7'b01101_11} ; // c.lui       -->  lui  rd, nzuimm[17:12]
      16'b100_?_00_???_?????_01 : d = {       7'b0000000,  shiftImm, rch, 3'b101,                 rch, 7'b00100_11} ; // c.srli      -->  srli rd', rd', shamt[5:0]
      16'b100_?_01_???_?????_01 : d = {       7'b0100000,  shiftImm, rch, 3'b101,                 rch, 7'b00100_11} ; // c.srai      -->  srai rd', rd', shamt[5:0]
      16'b100_?_10_???_?????_01 : d = {           addImm,            rch, 3'b111,                 rch, 7'b00100_11} ; // c.andi      -->  andi rd', rd', imm[5:0]
      16'b100_011_???_00_???_01 : d = {       7'b0100000,       rcl, rch, 3'b000,                 rch, 7'b01100_11} ; // c.sub       -->  sub  rd', rd', rs2'
      16'b100_011_???_01_???_01 : d = {       7'b0000000,       rcl, rch, 3'b100,                 rch, 7'b01100_11} ; // c.xor       -->  xor  rd', rd', rs2'
      16'b100_011_???_10_???_01 : d = {       7'b0000000,       rcl, rch, 3'b110,                 rch, 7'b01100_11} ; // c.or        -->  or   rd', rd', rs2'
      16'b100_011_???_11_???_01 : d = {       7'b0000000,       rcl, rch, 3'b111,                 rch, 7'b01100_11} ; // c.and       -->  and  rd', rd', rs2'
      16'b101____???????????_01 : d = {     jalImm[20], jalImm[10:1], jalImm[11], jalImm[19:12],   x0, 7'b11011_11} ; // c.j         -->  jal  x0, offset[11:1]
      16'b110__???_???_?????_01 : d = {bImm[12], bImm[10:5],     x0, rch, 3'b000, bImm[4:1], bImm[11], 7'b11000_11} ; // c.beqz      -->  beq  rs1', x0, offset[8:1]
      16'b111__???_???_?????_01 : d = {bImm[12], bImm[10:5],     x0, rch, 3'b001, bImm[4:1], bImm[11], 7'b11000_11} ; // c.bnez      -->  bne  rs1', x0, offset[8:1]

      16'b000__?_?????_?????_10 : d = {        7'b0000000, shiftImm, rwh, 3'b001,                 rwh, 7'b00100_11} ; // c.slli      -->  slli rd, rd, shamt[5:0]
      16'b010__?_?????_?????_10 : d = {           lwspImm,            x2, 3'b010,                 rwh, 7'b00000_11} ; // c.lwsp      -->  lw   rd, offset[7:2](x2)
      16'b100__0_?????_00000_10 : d = {  12'b000000000000,           rwh, 3'b000,                  x0, 7'b11001_11} ; // c.jr        -->  jalr x0, rs1, 0
      16'b100__0_?????_?????_10 : d = {        7'b0000000,      rwl,  x0, 3'b000,                 rwh, 7'b01100_11} ; // c.mv        -->  add  rd, x0, rs2
   // 16'b100__1_00000_00000_10 : d = {                              25'b00000000_00010000_00000000_0, 7'b11100_11} ; // c.ebreak    -->  ebreak
      16'b100__1_?????_00000_10 : d = {  12'b000000000000,           rwh, 3'b000,                  x1, 7'b11001_11} ; // c.jalr      -->  jalr x1, rs1, 0
      16'b100__1_?????_?????_10 : d = {        7'b0000000,      rwl, rwh, 3'b000,                 rwh, 7'b01100_11} ; // c.add       -->  add  rd, rd, rs2
      16'b110__?_?????_?????_10 : d = {     swspImm[11:5],      rwl,  x2, 3'b010,        swspImm[4:0], 7'b01000_11} ; // c.swsp      -->  sw   rs2, offset[7:2](x2)

      default:                    d =                                                                       unknown ; // Unknown opcode
   endcase
endmodule

/*****************************************************************************/
