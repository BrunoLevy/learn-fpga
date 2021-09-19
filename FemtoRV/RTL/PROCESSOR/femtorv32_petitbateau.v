/******************************************************************************/
// FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
//
// This version: PetitBateau (make it float), RV32IMFC
// Rounding works as follows:
// - all subnormals are flushed to zero
// - FADD, FSUB, FMUL, FMADD, FMSUB, FNMADD, FNMSUB: IEEE754 round to zero
// - FDIV and FSQRT do not have correct rounding
//
// [TODO] add FPU CSR (and instret for perf stat)]
// [TODO] FSW/FLW unaligned (does not seem to occur, but the norm requires it)
// [TODO] correct IEEE754 round to zero for FDIV and FSQRT
// [TODO] support IEEE754 denormals
// [TODO] NaNs propagation and infinity
// [TODO] support all IEEE754 rounding modes
//
// Bruno Levy, Matthias Koch, 2020-2021
/******************************************************************************/

// Firmware generation flags for this processor
//    Note: atomic instructions not supported, but 'a' is set in
//    compiler flag, because there is no toolchain/libs for
//    rv32imfc / imf in most risc-V compiler distributions.

`define NRV_ARCH     "rv32imafc" 
`define NRV_ABI      "ilp32f"

`define NRV_OPTIMIZE "-O3"
`define NRV_INTERRUPTS

// Check condition and display message in simulation
`ifdef BENCH
 `define ASSERT(cond,msg) if(!(cond)) $display msg
 `define ASSERT_NOT_REACHED(msg) $display msg
`else
 `define ASSERT(cond,msg)
 `define ASSERT_NOT_REACHED(msg)
`endif

// FPU Normalization needs to detect the position of the first bit set 
// in the A_frac register. It is easier to count the number of leading 
// zeroes (CLZ for Count Leading Zeroes), as follows. See:
// https://electronics.stackexchange.com/questions/196914/
//    verilog-synthesize-high-speed-leading-zero-count
// TODO: test also Dean Gaudet's algorithm (see Hackers Delights p. 110)
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

   // Flip a 32 bit word. Used by the shifter (a single shifter for
   // left and right shifts, saves silicium !)
   function [31:0] flip32;
      input [31:0] x;
      flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7], 
		x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15], 
		x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
		x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
   endfunction

   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 24;

   localparam ADDR_PAD = {(32-ADDR_WIDTH){1'b0}}; // 32-bits padding for addrs

   /***************************************************************************/
   // Instruction decoding.
   /***************************************************************************/

   // Reference: Table page 104 of:
   // https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf

   wire [2:0] funct3 = instr[14:12];
   
   // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
   // It is used as follows: funct3Is[val] <=> funct3 == val
   (* onehot *) wire [7:0] funct3Is = 8'b00000001 << instr[14:12];

   // The five imm formats, see RiscV reference (link above), Fig. 2.4 p. 12
   wire [31:0] Uimm={    instr[31],   instr[30:12], {12{1'b0}}};
   wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
   /* verilator lint_off UNUSED */ // MSBs of SBJimms not used by addr adder.
   wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
   wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
   wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};
   /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions !
   wire isLoad    =  (instr[6:3] == 4'b0000 ); // rd <-mem[rs1+Iimm] (bit 2:FLW)
   wire isALUimm  =  (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm   
   wire isAUIPC   =  (instr[6:2] == 5'b00101); // rd <- PC + Uimm
   wire isStore   =  (instr[6:3] == 4'b0100 ); // mem[rs1+Simm]<-rs2 (bit 2:FSW)
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
   reg [31:0] rs3; // this one is used by the FMA instructions.
   
   reg [31:0] registerFile [63:0]; //  0..31: integer registers
                                   // 32..63: floating-point registers
   
   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except divisions.
   /***************************************************************************/

   // First ALU source, always rs1
   wire [31:0] aluIn1 = rs1;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch:     rs2
   //    ALUimm, Load, JALR: Iimm
   wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

   wire aluWr; // ALU write strobe, starts dividing.

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

   wire signed [63:0]  multiply = signed1 * signed2;      
   
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
     ( funct3Is[0]   ?  multiply[31: 0] : 32'b0) | // 0:MUL
     (|funct3Is[3:1] ?  multiply[63:32] : 32'b0) | // 1:MULH, 2:MULHSU, 3:MULHU
     ( instr[14]     ?  div_sign ? -divResult : divResult : 32'b0) ; 
                                                // 4:DIV, 5:DIVU, 6:REM, 7:REMU

   wire [31:0] aluOut = isALUreg & funcM ? aluOut_muldiv : aluOut_base;

   /***************************************************************************/
   // Implementation of DIV/REM instructions, highly inspired by PicoRV32

   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;

   wire divstep_do = (divisor <= {31'b0, dividend});

   wire [31:0] dividendN = divstep_do ? dividend - divisor[31:0] : dividend;
   wire [31:0] quotientN = divstep_do ? quotient | quotient_msk  : quotient;

   wire div_sign = ~instr[12] & (instr[13] ? aluIn1[31] : 
                                     (aluIn1[31] != aluIn2[31]) & |aluIn2);
   always @(posedge clk) begin
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

   wire predicate = funct3Is[0] &  EQ  | // BEQ
                    funct3Is[1] & !EQ  | // BNE
                    funct3Is[4] &  LT  | // BLT
                    funct3Is[5] & !LT  | // BGE
                    funct3Is[6] &  LTU | // BLTU
                    funct3Is[7] & !LTU ; // BGEU

   /***************************************************************************/
   // The FPU 
   /***************************************************************************/

   // Uncomment the line below to emulate all FPU instructions in Verilator
   // (useful to test instruction decoder and implementations of micro-instr
   // in C++). See SIM/FPU_funcs.{h,cpp}
//`define FPU_EMUL
   
   // FPU output = 32 MSBs of A register (see below)
   // A macro to easily write to it (`FPU_OUT <= ...),
   // used when FPU output is an integer.
   `define FPU_OUT {A_sign, A_exp[7:0], A_frac[46:24]}
   wire [31:0] fpuOut = `FPU_OUT;   
  
   // Two temporary 32-bit registers used by FDIV and FSQRT
   reg [31:0] tmp1;
   reg [31:0] tmp2;
   
   // Expand the source registers into sign, exponent and fraction.
   // Normalized, first bit set is bit 23 (addditional bit), or zero.
   // For now, flush all denormals to zero
   // TODO: denormals and infinities
   // Following IEEE754, represented number is +/- frac * 2^(exp-127-23)
   // (127: bias  23: position of first bit set for normalized numbers)
   
   wire        rs1_sign = rs1[31];
   wire [7:0]  rs1_exp  = rs1[30:23];
   wire [23:0] rs1_frac = rs1_exp == 8'd0 ? 24'b0 : {1'b1, rs1[22:0]};
   
   wire        rs2_sign = rs2[31];
   wire [7:0]  rs2_exp  = rs2[30:23];
   wire [23:0] rs2_frac = rs2_exp == 8'd0 ? 24'b0 : {1'b1, rs2[22:0]};
   
   wire        rs3_sign = rs3[31];
   wire [7:0]  rs3_exp  = rs3[30:23];
   wire [23:0] rs3_frac = rs3_exp == 8'd0 ? 24'b0 : {1'b1, rs3[22:0]};

   // Two high-resolution registers
   // Register A has the accumulator / shifters / leading zero counter
   // Normalized if first bit set is bit 47
   // Represented number is +/- frac * 2^(exp-127-47)
   
   reg 	             A_sign;
   reg signed [8:0]  A_exp;
   reg signed [49:0] A_frac;
   
   reg 	             B_sign;
   reg signed [8:0]  B_exp;
   reg signed [49:0] B_frac;

   // Some circuitry used by the FPU micro-instructions:

   // ******************* Comparisons ******************************************
   // Exponent adder
   wire signed [8:0]  exp_sum   = B_exp + A_exp;
   wire signed [8:0]  exp_diff  = B_exp - A_exp;
   
   wire expA_EQ_expB   = (exp_diff  == 0);
   wire fracA_EQ_fracB = (frac_diff == 0);
   wire fabsA_EQ_fabsB = (expA_EQ_expB && fracA_EQ_fracB);
   wire fabsA_LT_fabsB = (!exp_diff[8] && !expA_EQ_expB) || 
                           (expA_EQ_expB && !fracA_EQ_fracB && !frac_diff[50]);

   wire fabsA_LE_fabsB = (!exp_diff[8] && !expA_EQ_expB) || 
                                              (expA_EQ_expB && !frac_diff[50]);
   
   wire fabsB_LT_fabsA = exp_diff[8] || (expA_EQ_expB && frac_diff[50]);

   wire fabsB_LE_fabsA = exp_diff[8] || 
                           (expA_EQ_expB && (frac_diff[50] || fracA_EQ_fracB));

   wire A_LT_B = A_sign && !B_sign ||
	         A_sign &&  B_sign && fabsB_LT_fabsA ||
 		!A_sign && !B_sign && fabsA_LT_fabsB ;

   wire A_LE_B = A_sign && !B_sign ||
		 A_sign &&  B_sign && fabsB_LE_fabsA ||
 	        !A_sign && !B_sign && fabsA_LE_fabsB ;
   
   wire A_EQ_B = fabsA_EQ_fabsB && (A_sign == B_sign);

   // ****************** Addition, subtraction *********************************
   wire signed [50:0] frac_sum  = B_frac + A_frac;
   wire signed [50:0] frac_diff = B_frac - A_frac;

   // ****************** Product ***********************************************
   wire [49:0] prod_frac = rs1_frac * rs2_frac; // TODO: check overflows

   // exponent of product, once normalized
   // (obtained by writing expression of product and inspecting exponent)
   // Two cases: first bit set = 47 or 46 (only possible cases with normals)
   wire signed [8:0] prod_exp_norm = rs1_exp+rs2_exp-127+{7'b0,prod_frac[47]};

   // detect null product and underflows (all denormals are flushed to zero)
   wire prod_Z = (prod_exp_norm <= 0) || !(|prod_frac[47:46]);
   
   // ****************** Normalization *****************************************
   // Count leading zeroes in A+B
   // Note1: CLZ only work with power of two width (hence 14'b0).
   // Note2: first bit set = 63 - CLZ (of course !)
   wire [5:0] 	              frac_sum_clz;
   CLZ clz2({13'b0,frac_sum}, frac_sum_clz);
   reg [5:0] 		      norm_lshamt; // shift amount for ADD normalization

   // Exponent of A once normalized = A_exp + first_bit_set - 47
   //                               = A_exp + 63 - clz - 47 = A_exp + 16 - clz
   // wire signed [8:0] A_exp_norm = A_exp + 16 - {3'b000,A_clz};
   reg signed [8:0] A_exp_norm;
   
   // ****************** Reciprocal (1/x), used by FDIV ************************
   // Exponent for reciprocal (1/x)
   // Initial value of x kept in tmp2.
   wire signed [8:0]  frcp_exp  = 9'd126 + A_exp - $signed({1'b0, tmp2[30:23]});

   // ****************** Reciprocal square root (1/sqrt(x)) ********************
   // https://en.wikipedia.org/wiki/Fast_inverse_square_root
   wire [31:0] rsqrt_doom_magic = 32'h5f3759df - {1'b0,rs1[30:1]};

   
   // ****************** Float to Integer conversion ***************************
   // -127-23 is standard exponent bias
   // -6 because it is bit 29 of rs1 that corresponds to bit 47 of A_frac,
   //    instead of bit 23 (and 23-29 = -6).
   wire signed [8:0]  fcvt_ftoi_shift = rs1_exp - 9'd127 - 9'd23 - 9'd6; 
   wire signed [8:0]  neg_fcvt_ftoi_shift = -fcvt_ftoi_shift;
   
   wire [31:0] 	A_fcvt_ftoi_shifted =  fcvt_ftoi_shift[8] ? // R or L shift
                        (|neg_fcvt_ftoi_shift[8:5]  ?  0 :  // underflow
                     ({A_frac[49:18]} >> neg_fcvt_ftoi_shift[4:0])) : 
                     ({A_frac[49:18]} << fcvt_ftoi_shift[4:0]);
  
   // ******************* Classification ***************************************
   wire rs1_exp_Z   = (rs1_exp  == 0  );
   wire rs1_exp_255 = (rs1_exp  == 255);
   wire rs1_frac_Z  = (rs1_frac == 0  );

   wire [31:0] fclass = {
      22'b0,				    
      rs1_exp_255 & rs1_frac[22],                      // 9: quiet NaN
      rs1_exp_255 & !rs1_frac[22] & (|rs1_frac[21:0]), // 8: sig   NaN
              !rs1_sign &  rs1_exp_255 & rs1_frac_Z,   // 7: +infinity
              !rs1_sign & !rs1_exp_Z   & !rs1_exp_255, // 6: +normal
              !rs1_sign &  rs1_exp_Z   & !rs1_frac_Z,  // 5: +subnormal
              !rs1_sign &  rs1_exp_Z   & rs1_frac_Z,   // 4: +0  
               rs1_sign &  rs1_exp_Z   & rs1_frac_Z,   // 3: -0
               rs1_sign &  rs1_exp_Z   & !rs1_frac_Z,  // 2: -subnormal
               rs1_sign & !rs1_exp_Z   & !rs1_exp_255, // 1: -normal
               rs1_sign &  rs1_exp_255 & rs1_frac_Z    // 0: -infinity
   };
   
   /** FPU micro-instructions and ROM ****************************************/

   // Set to 1 for higher-precision FDIV (costs 12 additional cycles per FDIV)
   localparam PRECISE_DIV = 0;
   
   localparam FPMI_READY           = 0; 
   localparam FPMI_LOAD_AB         = 1;   // A <- rs1; B <- rs2
   localparam FPMI_LOAD_AB_MUL     = 2;   // A <- norm(rs1*rs2); B <- rs3
   localparam FPMI_ADD_SWAP        = 3;   // if |A|>|B| swap(A,B);
                                          // if sign(A) != sign(B) A <- -A
   localparam FPMI_ADD_SHIFT       = 4;   // shift A to match B exponent
   localparam FPMI_ADD_ADD         = 5;   // A <- A + B   (or A - B if FSUB)
   localparam FPMI_ADD_NORM        = 6;   // A <- norm(A) (after ADD_ADD)
   
   localparam FPMI_CMP             = 7;   // fpuOut <- test A,B (FEQ,FLE,FLT)

   localparam FPMI_MV_RS1_A        =  8;  // rs1 <- A
   localparam FPMI_MV_RS2_TMP1     =  9;  // rs1 <- tmp1
   localparam FPMI_MV_RS2_MHTMP1   = 10;  // rs2 <- -0.5*tmp1
   localparam FPMI_MV_RS2_TMP2     = 11;  // rs2 <- tmp2
   localparam FPMI_MV_TMP2_A       = 12;  // tmp2  <- A

   localparam FPMI_FRCP_PROLOG     = 13;  // init reciprocal (1/x) 
   localparam FPMI_FRCP_ITER1      = 14;  // iteration for reciprocal
   localparam FPMI_FRCP_ITER2      = 15;  // iteration for reciprocal   
   localparam FPMI_FRCP_EPILOG     = 16;  // epilog for reciprocal
   
   localparam FPMI_FRSQRT_PROLOG   = 17;  // init recipr sqr root (1/sqrt(x))
   
   localparam FPMI_FP_TO_INT       = 18;  // fpuOut <- fpoint_to_int(rs1)
   localparam FPMI_INT_TO_FP       = 19;  // A <- int_to_fpoint(rs1)
   localparam FPMI_MIN_MAX         = 20;  // fpuOut <- min/max(A,B) 

   localparam FPMI_NB              = 21;

   // Instruction exit flag (if set in current micro-instr, exit microprogram)
   localparam FPMI_EXIT_FLAG_bit   = 1+$clog2(FPMI_NB);
   localparam FPMI_EXIT_FLAG       = 1 << FPMI_EXIT_FLAG_bit;
   
   reg [6:0] 	             fpmi_PC;    // current micro-instruction pointer
   reg [1+$clog2(FPMI_NB):0] fpmi_instr; // current micro-instruction

   // current micro-instruction as 1-hot: fpmi_instr == NNN <=> fpmi_is[NNN]
   (* onehot *)
   wire [FPMI_NB-1:0] fpmi_is = 1 << fpmi_instr[$clog2(FPMI_NB):0]; 
   initial fpmi_PC = 0;
   wire fpuBusy = !fpmi_is[FPMI_READY];

   // Generate a micro-instructions in ROM 
   task fpmi_gen; input [6:0] instr; begin
      fpmi_ROM[I] = instr;
      I = I + 1;
   end endtask   

   // Generate a FMA sequence in ROM.
   // Use fpmi_gen_fma(0) in the middle of a micro-program
   // Use fpmi_gen_fma(FPMI_EXIT_FLAG) if last instruction of micro-program
   task fpmi_gen_fma; input [6:0] flags; begin
      fpmi_gen(FPMI_LOAD_AB_MUL);      // A <- norm(rs1*rs2), B <- rs3  
      fpmi_gen(FPMI_ADD_SWAP);         // if(|A| > |B|) swap(A,B) (and sgn)
      fpmi_gen(FPMI_ADD_SHIFT);        // shift A according to B exp
      fpmi_gen(FPMI_ADD_ADD);          // A <- A + B  ( or A - B if FSUB)
      fpmi_gen(FPMI_ADD_NORM | flags); // A <- normalize(A)
   end endtask
   
   integer I;    // current ROM location in initialization
   integer iter; // iteration variable for Newton-Raphson (FDIV,FSQRT)
   localparam FPMI_ROM_SIZE=82 + 12*PRECISE_DIV; 
   reg [1+$clog2(FPMI_NB):0] fpmi_ROM[0:FPMI_ROM_SIZE-1];

   // Microprograms start addresses
   // Programatically determined when generating the ROM ('initial' block below)
   integer FPMPROG_CMP, FPMPROG_ADD, FPMPROG_MUL, FPMPROG_MADD, FPMPROG_DIV;
   integer FPMPROG_TO_INT, FPMPROG_INT_TO_FP, FPMPROG_SQRT, FPMPROG_MIN_MAX;

   // Start the definition of a microprogram (determines start address)
   `define FPMPROG_BEGIN(prg) prg = I

   // Ends the definition of a microprogram (displays stats in Verilator)
   `ifdef BENCH
    `define FPMPROG_END(prg) \
        $display("%3d microinstructions used by %s",I-prg,`"prg`")
   `else
    `define FPMPROG_END(prg) 
   `endif

   /******************** Generate microprograms in ROM **********************/
   initial begin

   `ifdef BENCH
      $display("Generating FPMI ROM...");
   `endif
      I = 0;
      fpmi_gen(FPMI_READY | FPMI_EXIT_FLAG);

      // ******************** FLT, FLE, FEQ *********************************
      `FPMPROG_BEGIN(FPMPROG_CMP);
      fpmi_gen(FPMI_LOAD_AB); // A <- rs1, B <- rs2
      fpmi_gen(FPMI_CMP | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_CMP);
      
      // ******************** FADD, FSUB ************************************
      `FPMPROG_BEGIN(FPMPROG_ADD);
      fpmi_gen(FPMI_LOAD_AB);               // A <- rs1, B <- rs2
      fpmi_gen(FPMI_ADD_SWAP);              // if(|A| > |B|) swap(A,B) (and sgn)
      fpmi_gen(FPMI_ADD_SHIFT);             // shift A according to B exp
      fpmi_gen(FPMI_ADD_ADD);               // A <- A + B  ( or A - B if FSUB)
      fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG); // A <- normalize(A)
      `FPMPROG_END(FPMPROG_ADD);
      
      // ******************** FMUL ******************************************
      `FPMPROG_BEGIN(FPMPROG_MUL);
      fpmi_gen(FPMI_LOAD_AB_MUL | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_MUL);

      // ******************** FMADD, FMSUB, FNMADD, FNMSUB ******************
      `FPMPROG_BEGIN(FPMPROG_MADD);
      fpmi_gen_fma(FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_MADD);      

      // ******************** FDIV ******************************************
      // https://en.wikipedia.org/wiki/Division_algorithm
      // https://stackoverflow.com/questions/24792966/
      // error-using-newton-raphson-iteration-method-for-
      // floating-point-division
      //
      `FPMPROG_BEGIN(FPMPROG_DIV);      
      // D' <- rs2 normalized between [0.5,1] (set exp to 126)
      fpmi_gen(FPMI_FRCP_PROLOG);   // A <- -D'*32/17 + 48/17
      fpmi_gen_fma(0);
      for(iter=0; iter<3; iter++) begin
	 if(PRECISE_DIV) begin
	    // A <- A + A*(1-D'*A)
	    // (slower more precise iter, but not IEEE754 compliant yet...)
	    fpmi_gen(FPMI_FRCP_ITER1);
	    fpmi_gen_fma(0); // 5 cycles
	    fpmi_gen(FPMI_FRCP_ITER2);
	    fpmi_gen_fma(0); // 5 cycles	 
	 end else begin
	    //  A <- A * (-A*D + 2)
	    // (faster but less precise)
	    fpmi_gen(FPMI_FRCP_ITER1);     
	    fpmi_gen_fma(0); // 5 cycles
	    fpmi_gen(FPMI_MV_RS1_A);
	    fpmi_gen(FPMI_LOAD_AB_MUL);
	 end
      end
      fpmi_gen(FPMI_FRCP_EPILOG); // A  <- rs1 * A
      fpmi_gen(FPMI_LOAD_AB_MUL | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_DIV);      
      
      // ******************** FCVT.W.S, FCVT.WU.S ***************************
      `FPMPROG_BEGIN(FPMPROG_TO_INT);
      fpmi_gen(FPMI_LOAD_AB);
      fpmi_gen(FPMI_FP_TO_INT | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_TO_INT);      
      
      // ******************** FCVT.S.W, FCVT.S.WU ***************************
      `FPMPROG_BEGIN(FPMPROG_INT_TO_FP);
      fpmi_gen(FPMI_INT_TO_FP);
      fpmi_gen(FPMI_ADD_ADD);
      fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_INT_TO_FP);
      
      // ******************** FSQRT *****************************************
      // Using Doom's fast inverse square root algorithm:
      // https://en.wikipedia.org/wiki/Fast_inverse_square_root
      // http://www.lomont.org/papers/2003/InvSqrt.pdf
      // TODO: IEEE754-compliant version
      // See https://t.co/V1SWQ6N6xD?amp=1 (Method of Switching Constants)
      // See simple effective fast inverse square root with two magic constants
      //
      `FPMPROG_BEGIN(FPMPROG_SQRT);
      // A <- doom_magic - (A >> 1)      
      fpmi_gen(FPMI_FRSQRT_PROLOG);
      for(iter=0; iter<2; iter++) begin
	 // A <- A * (3/2 - (rs1/2 * A * A))      	 
	 fpmi_gen(FPMI_LOAD_AB_MUL);
	 fpmi_gen(FPMI_MV_RS1_A);
         fpmi_gen(FPMI_MV_RS2_MHTMP1);
	 fpmi_gen_fma(0);
	 fpmi_gen(FPMI_MV_RS1_A);
	 fpmi_gen(FPMI_MV_RS2_TMP2);
	 fpmi_gen(FPMI_LOAD_AB_MUL);
	 if(iter==0) begin
	    fpmi_gen(FPMI_MV_TMP2_A);
	    fpmi_gen(FPMI_MV_RS1_A);
	    fpmi_gen(FPMI_MV_RS2_TMP2);
	 end
      end // Now A contains an approx of 1/sqrt(rs1)
      // A <- A * rs1
      fpmi_gen(FPMI_MV_RS1_A);
      fpmi_gen(FPMI_MV_RS2_TMP1);
      fpmi_gen(FPMI_LOAD_AB_MUL | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_SQRT);
      
      // ******************** FMIN, FMAX ************************************
      `FPMPROG_BEGIN(FPMPROG_MIN_MAX);
      fpmi_gen(FPMI_LOAD_AB);
      fpmi_gen(FPMI_MIN_MAX | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_MIN_MAX);
      
`ifdef BENCH      
      $display("FPMI ROM max address:%d",I-1);
      $display("FPMI ROM size       :%d",FPMI_ROM_SIZE);      
      `ASSERT(I <= FPMI_ROM_SIZE,("!!!!!!! FPMI ROM SIZE exceeded !!!!!!!"));
`endif      
   end

   // FPU micro-code next instruction
   wire [6:0] fpmi_PC_next = 
               (state[EXECUTE_bit] & isFPU)   ? fpmprog   :
	       fpmi_instr[FPMI_EXIT_FLAG_bit] ? 0         : 
                                                fpmi_PC+1 ;
   
   /*************************************************************************/

`ifndef FPU_EMUL
   always @(posedge clk) begin
      fpmi_PC <= fpmi_PC_next;
      fpmi_instr <= fpmi_ROM[fpmi_PC_next];
   end
`endif
   
   always @(posedge clk) begin
      if(state[WAIT_INSTR_bit]) begin
	 // Fetch registers as soon as instruction is ready.
	 rs1 <= registerFile[{raw_rs1IsFP,raw_instr[19:15]}]; 
	 rs2 <= registerFile[{raw_rs2IsFP,raw_instr[24:20]}];
	 rs3 <= registerFile[{1'b1,       raw_instr[31:27]}];
      end else if(state[DECOMPRESS_GETREGS_bit]) begin
	 // For compressed instructions, fetch registers once decompressed.
	 rs1 <= registerFile[{decomp_rs1IsFP,instr[19:15]}];
	 rs2 <= registerFile[{decomp_rs2IsFP,instr[24:20]}];
	 // no need to fetch rs3 here, there is no compressed FMA.
      end else if(state[EXECUTE_bit] & isFPU) begin
`ifndef FPU_EMUL
	 (* parallel_case *)
	 case(1'b1)
	   // Single-cycle instructions
	   isFSGNJ           : `FPU_OUT <= {         rs2[31], rs1[30:0]};
	   isFSGNJN          : `FPU_OUT <= {        !rs2[31], rs1[30:0]};
	   isFSGNJX          : `FPU_OUT <= { rs1[31]^rs2[31], rs1[30:0]};
	   isFCLASS          : `FPU_OUT <= fclass;
           isFMVXW | isFMVWX : `FPU_OUT <= rs1;
	 endcase 
`endif 
      end else if(fpuBusy) begin 
	 // Implementation of the micro-instructions	 
	 (* parallel_case *)	 
	 case(1'b1)
	   // A <- rs1 ; B <- rs2
	   fpmi_is[FPMI_LOAD_AB]: begin
	      A_sign <= rs1_sign;
	      A_frac <= {2'b0, rs1_frac, 24'd0};
	      A_exp  <= {1'b0, rs1_exp}; 
	      B_sign <= rs2_sign ^ isFSUB;
	      B_frac <= {2'b0, rs2_frac, 24'd0};
	      B_exp  <= {1'b0, rs2_exp}; 
	   end

	   // A <- (+/-) normalize(rs1*rs2);  B <- (+/-)rs3
	   fpmi_is[FPMI_LOAD_AB_MUL]: begin
	      A_sign <= rs1_sign ^ rs2_sign ^ (isFNMSUB | isFNMADD);
	      A_frac <= prod_Z ? 0 :  
                          (prod_frac[47] ? prod_frac : {prod_frac[48:0],1'b0}); 
	      A_exp  <= prod_Z ? 0 : prod_exp_norm;
	      
	      B_sign <= rs3_sign ^ (isFMSUB | isFNMADD);
	      B_frac <= {2'b0, rs3_frac, 24'd0};
	      B_exp  <= {1'b0, rs3_exp};
	   end

	   // A <- normalize(A) (after ADD_ADD -> norm_lshamt and A_exp_norm)
	   fpmi_is[FPMI_ADD_NORM]: begin
	      if(A_exp_norm <= 0 || (A_frac == 0)) begin
		 A_frac <= 0;
		 A_exp <= 0;
	      end else begin
		 A_frac <= A_frac[48] ? (A_frac >> 1) : A_frac << norm_lshamt;
		 A_exp  <= A_exp_norm;
		 // $display("CLZ %b %d",{14'b0,A_frac},A_clz); 
	      end
	   end

	   // if(|A| > |B|) swap(A,B)
	   // if A_sign != B_sign A <- -A
	   // We always *add*, but replace A_frac with -A_frac if the
	   // sign of the operands differ, THEN we shift (signed shift). In
	   // this way, rounding is correct, even when subtracting a
	   // low magnitude numner from a large magnitude one.
	   fpmi_is[FPMI_ADD_SWAP]: begin
	      if(fabsB_LT_fabsA) begin
		 A_frac <= (A_sign ^ B_sign) ? -B_frac : B_frac; 
		 B_frac <= A_frac;
		 A_exp  <= B_exp;  B_exp  <= A_exp;
		 A_sign <= B_sign; B_sign <= A_sign;
	      end else if(A_sign ^ B_sign) begin
		 A_frac <= -A_frac;
	      end
	   end

	   // shift A in order to make it match B exponent
	   fpmi_is[FPMI_ADD_SHIFT]: begin
	      `ASSERT(!fabsB_LT_fabsA, ("ADD_SHIFT: incorrect order"));
	      A_frac <= A_frac >>> exp_diff; // note the signed shift !
	      A_exp <= B_exp;
	   end

	   // A <- A (+/-) B
	   fpmi_is[FPMI_ADD_ADD]: begin
	      A_frac      <= frac_sum[49:0];
	      A_sign      <= B_sign;
	      // normalization left shamt = 47 - first_bit_set = clz - 16
	      norm_lshamt <= frac_sum_clz - 16;
	      // Exponent of A once normalized = A_exp + first_bit_set - 47
	      //                 = A_exp + 63 - clz - 47 = A_exp + 16 - clz
	      A_exp_norm <= A_exp + 16 - {3'b000,frac_sum_clz};
	   end

	   // A <- result of comparison between A and B
	   fpmi_is[FPMI_CMP]: begin
	      `FPU_OUT <= { 31'b0, 
			    isFLT && A_LT_B || 
			    isFLE && A_LE_B || 
			    isFEQ && A_EQ_B
                          };
	   end

	   fpmi_is[FPMI_MV_RS2_TMP1] : rs2 <= tmp1;
	   fpmi_is[FPMI_MV_RS2_TMP2] : rs2 <= tmp2;	   
	   fpmi_is[FPMI_MV_RS1_A]  : rs1  <= {A_sign,A_exp[7:0],A_frac[46:24]};
	   fpmi_is[FPMI_MV_TMP2_A] : tmp2 <= {A_sign,A_exp[7:0],A_frac[46:24]};
	   
	   // rs2 <= -|tmp1| / 2.0
	   fpmi_is[FPMI_MV_RS2_MHTMP1]:rs2<={1'b1,tmp1[30:23]-8'd1,tmp1[22:0]};

	   fpmi_is[FPMI_FRCP_PROLOG]: begin
	      tmp1 <= rs1;
	      tmp2 <= rs2;
	      // rs1 <= -D', that is, -(rs2 normalized in [0.5,1])
	      rs1  <= {1'b1, 8'd126, rs2_frac[22:0]}; 
	      rs2  <= 32'h3FF0F0F1; // 32/17
	      rs3  <= 32'h4034B4B5; // 48/17
	   end
	   
	   fpmi_is[FPMI_FRCP_ITER1]: begin
	      rs1  <= {1'b1, 8'd126, tmp2[22:0]};                // -D'
	      rs2  <= {A_sign, A_exp[7:0], A_frac[46:24]};       // A
	      rs3  <= PRECISE_DIV ? 32'h3f800000 : 32'h40000000; //p ? 1.0 : 2.0
	   end

	   // This one is used only if PRECISE_DIV is set
	   fpmi_is[FPMI_FRCP_ITER2]: begin
	      rs1 <= {A_sign, A_exp[7:0], A_frac[46:24]}; // A
	      rs3 <= rs2;
	   end
	   
	   fpmi_is[FPMI_FRCP_EPILOG]: begin
	      rs1 <= {tmp2[31], frcp_exp[7:0], A_frac[46:24]}; 
	      rs2 <= tmp1;
	   end
	   
	   fpmi_is[FPMI_FRSQRT_PROLOG]: begin
	      tmp1 <= rs1;
	      tmp2 <= rsqrt_doom_magic;
	      rs1  <= rsqrt_doom_magic;
	      rs2  <= rsqrt_doom_magic;
	      rs3  <= 32'h3fc00000; // 1.5
	   end
	   
	   fpmi_is[FPMI_FP_TO_INT]: begin
	      // TODO: check overflow
	      `FPU_OUT <= 
               (isFCVTWUS | !A_sign) ? A_fcvt_ftoi_shifted 
                                     : -$signed(A_fcvt_ftoi_shifted);
	   end

	   fpmi_is[FPMI_INT_TO_FP]: begin
	      // TODO: rounding

	      // We do a fake addition with zero, to prepare normalization
	      // (uses CLZ plugged on the adder).
	      A_frac <= 0;
	      // 127+23: standard exponent bias
	      // +6 because it is bit 29 of rs1 that overwrites 
	      //    bit 47 of A_frac, instead of bit 23 (and 29-23 = 6).
	      A_exp  <= 127+23+6;
	      B_frac <=  (isFCVTSWU | !rs1[31]) ? {rs1, 18'd0}
                                                : {-$signed(rs1), 18'd0};
	      B_sign <= isFCVTSW & rs1[31];
	   end

	   fpmi_is[FPMI_MIN_MAX]: begin
	      `FPU_OUT <=  (A_LT_B ^ isFMAX)
		                 ? {A_sign, A_exp[7:0], A_frac[46:24]}
	 	                 : {B_sign, B_exp[7:0], B_frac[46:24]};
	   end
	 endcase 

      // register write-back
      end else if(writeBack) begin 
	 if(rdIsFP || |instr[11:7]) begin
            registerFile[{rdIsFP,instr[11:7]}] <= writeBackData;
	 end
      end 
   end
   
   // RV32F instruction decoder
   // See table p133 (RV32G instruction listings)
   // Notes:
   //  - FLW/FSW handled by LOAD/STORE (instr[2] set if FLW/FSW)
   //  - For all other F instructions, instr[6:5] == 2'b10
   //  - FMADD/FMSUB/FNMADD/FNMSUB: instr[4] = 1'b0
   //  - For all remaining F instructions, instr[4] = 1'b1
   //  - FMV.X.W and FCLASS have same funct7 (7'b1110000),
   //      (discriminated by instr[12])
   //  - there is a big gotcha in the official doc for RV32F:
   //        the doc says FNMADD computes -rs1*rs2-rs3
   //          (yes, with *minus* rs3)
   //        it should have said FNMADD computes -(rs1*rs2+rs3)
   //                        and FNMSUB compures -(rs1*rs2-rs3)
   //        they probably did not put the parentheses because when
   //        you implement it, you change the sign of rs1 and rs3 according
   //        to the operation rather than the sign of the whole result
   //        (here, it is done by the FPMI_LOAD_AB_MUL micro instruction).
   
   wire isFMADD   = (instr[4:2] == 3'b000); // rd <-   rs1*rs2+rs3
   wire isFMSUB   = (instr[4:2] == 3'b001); // rd <-   rs1*rs2-rs3
   wire isFNMSUB  = (instr[4:2] == 3'b010); // rd <- -(rs1*rs2-rs3) 
   wire isFNMADD  = (instr[4:2] == 3'b011); // rd <- -(rs1*rs2+rs3) 

   wire isFADD    = (instr[4] && (instr[31:27] == 5'b00000));
   wire isFSUB    = (instr[4] && (instr[31:27] == 5'b00001));
   wire isFMUL    = (instr[4] && (instr[31:27] == 5'b00010));
   wire isFDIV    = (instr[4] && (instr[31:27] == 5'b00011));
   wire isFSQRT   = (instr[4] && (instr[31:27] == 5'b01011));   

   wire isFSGNJ =(instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b00));
   wire isFSGNJN=(instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b01));
   wire isFSGNJX=(instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b10));

   wire isFMIN    = (instr[4] && (instr[31:27] == 5'b00101) && !instr[12]);
   wire isFMAX    = (instr[4] && (instr[31:27] == 5'b00101) &&  instr[12]);

   wire isFEQ=(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b10));
   wire isFLT=(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b01));
   wire isFLE=(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b00));
   
   wire isFCLASS  = (instr[4] && (instr[31:27] == 5'b11100) &&  instr[12]); 
   
   wire isFCVTWS  = (instr[4] && (instr[31:27] == 5'b11000) && !instr[20]);
   wire isFCVTWUS = (instr[4] && (instr[31:27] == 5'b11000) &&  instr[20]);

   wire isFCVTSW  = (instr[4] && (instr[31:27] == 5'b11010) && !instr[20]);
   wire isFCVTSWU = (instr[4] && (instr[31:27] == 5'b11010) &&  instr[20]);

   wire isFMVXW   = (instr[4] && (instr[31:27] == 5'b11100) && !instr[12]);
   wire isFMVWX   = (instr[4] && (instr[31:27] == 5'b11110));


   // asserted if the destination register is a floating-point register
   wire rdIsFP = (instr[6:2] == 5'b00001)             || // FLW
	         (instr[6:4] == 3'b100  )             || // F{N}MADD,F{N}MSUB
	         (instr[6:4] == 3'b101 && (
                            (instr[31]    == 1'b0)    || // R-Type FPU
			    (instr[31:28] == 4'b1101) || // FCVT.S.W{U}
			    (instr[31:28] == 4'b1111)    // FMV.W.X 
			 )
                 );

   // rs1 is a FP register if instr[6:5] = 2'b10 except for:
   //   FCVT.S.W{U}:  instr[6:2] = 5'b10100 and instr[30:28] = 3'b101
   //   FMV.W.X    :  instr[6:2] = 5'b10100 and instr[30:28] = 3'b111
   // (two versions of the signal, one for regular instruction decode,
   //  the other one for compressed instructions).
   wire raw_rs1IsFP = (raw_instr[6:5]   == 2'b10 ) &&  
                     !((raw_instr[4:2]  == 3'b100) && (
                      (raw_instr[31:28] == 4'b1101) || // FCVT.S.W{U}
     	              (raw_instr[31:28] == 4'b1111)    // FMV.W.X
                    )						    
		  );

   wire decomp_rs1IsFP = (instr[6:5]   == 2'b10 ) &&  
                     !((instr[4:2]  == 3'b100) && (
                      (instr[31:28] == 4'b1101) || // FCVT.S.W{U}
     	              (instr[31:28] == 4'b1111)    // FMV.W.X
                    )						    
		  );
   
   // rs2 is a FP register if instr[6:5] = 2'b10 or instr is FSW
   // (two versions of the signal, one for regular instruction decode,
   //  the other one for compressed instructions).
   wire raw_rs2IsFP = (raw_instr[6:5] == 2'b10) || (raw_instr[6:2]==5'b01001);
   wire decomp_rs2IsFP =  (instr[6:5] == 2'b10) || (instr[6:2]==5'b01001);   

   // microprogram
   reg [6:0] fpmprog;
   always @(*) begin
      case(1'b1)
	isFLT   | isFLE   | isFEQ               : fpmprog = FPMPROG_CMP[6:0];
	isFADD  | isFSUB                        : fpmprog = FPMPROG_ADD[6:0];
	isFMUL                                  : fpmprog = FPMPROG_MUL[6:0];
	isFMADD | isFMSUB | isFNMADD | isFNMSUB : fpmprog = FPMPROG_MADD[6:0];
	isFDIV                                  : fpmprog = FPMPROG_DIV[6:0];
	isFSQRT                                 : fpmprog = FPMPROG_SQRT[6:0];
	isFCVTWS | isFCVTWUS  : fpmprog = FPMPROG_TO_INT[6:0];
	isFCVTSW | isFCVTSWU  : fpmprog = FPMPROG_INT_TO_FP[6:0];
	isFMIN   | isFMAX     : fpmprog = FPMPROG_MIN_MAX[6:0];
	default               : fpmprog = 0;
      endcase
   end

   
/****************************************************************************/
// Simulated instructions, implemented in C++ in SIM/FPU_funcs.cpp 
// (toggle C++ emul / Verilog FPU by defining FPU_EMUL)
   
`ifdef VERILATOR
`ifdef FPU_EMUL
   
 `define FPU_EMUL1(op) `FPU_OUT <= $c32(op,"(",rs1,")")
 `define FPU_EMUL2(op) `FPU_OUT <= $c32(op,"(",rs1,",",rs2,")")
 `define FPU_EMUL3(op) `FPU_OUT <= $c32(op,"(",rs1,",",rs2,",",rs3,")")
   
   always @(posedge clk) begin
      if(isFPU && state[EXECUTE_bit]) begin
	 case(1'b1)
	   isFMUL   : `FPU_EMUL2("FMUL");
	   isFADD   : `FPU_EMUL2("FADD");
	   isFSUB   : `FPU_EMUL2("FSUB");
	   isFDIV   : `FPU_EMUL2("FDIV");
	   isFSQRT  : `FPU_EMUL1("FSQRT");	   
	   isFMADD  : `FPU_EMUL3("FMADD");	  
	   isFMSUB  : `FPU_EMUL3("FMSUB");	  
	   isFNMADD : `FPU_EMUL3("FNMADD");	  
	   isFNMSUB : `FPU_EMUL3("FNMSUB");	  
	   isFEQ    : `FPU_EMUL2("FEQ");
	   isFLT    : `FPU_EMUL2("FLT");
	   isFLE    : `FPU_EMUL2("FLE");
	   isFCVTWS : `FPU_EMUL1("FCVTWS"); 
	   isFCVTWUS: `FPU_EMUL1("FCVTWUS");
	   isFCVTSW : `FPU_EMUL1("FCVTSW"); 
	   isFCVTSWU: `FPU_EMUL1("FCVTSWU"); 
	   isFMIN   : `FPU_EMUL2("FMIN");
	   isFMAX   : `FPU_EMUL2("FMAX");
	   isFCLASS : `FPU_EMUL1("FCLASS");
	   isFSGNJ  : `FPU_EMUL2("FSGNJ");
	   isFSGNJN : `FPU_EMUL2("FSGNJN");
	   isFSGNJX : `FPU_EMUL2("FSGNJX");
           isFMVXW  : `FPU_OUT <= rs1;
	   isFMVWX  : `FPU_OUT <= rs1;
         endcase		     
      end		     
   end 
`endif
`endif 

/****************************************************************************/
// When doing simulations, compare the result of all operations with
// what's computed on the host CPU. 
// Note1: checks use rs1_bkp, rs2_bkp, rs3_bkp because
//  FDIV and FSQRT overwrite rs1 and rs2
// Note2: my FDIV and FSQRT are not IEEE754 compliant (yet) ! 
// (checks commented-out for now)
   
`ifdef VERILATOR   

 `define FPU_CHECK1(op) \
       z <= $c32("CHECK_",op,"(",fpuOut,",",rs1_bkp,")")
 `define FPU_CHECK2(op) \
       z <= $c32("CHECK_",op,"(",fpuOut,",",rs1_bkp,",",rs2_bkp,")")
 `define FPU_CHECK3(op) \
       z <= $c32("CHECK_",op,"(",fpuOut,",",rs1_bkp,",",rs2_bkp,",",rs3_bkp,")")
   
   reg [31:0] z;
   reg [31:0] rs1_bkp;
   reg [31:0] rs2_bkp;
   reg [31:0] rs3_bkp;   

   always @(posedge clk) begin
      // Some micro-coded instructions (FDIV/FSQRT) use rs1, rs2 and
      // rs3 as temporaty registers, so we need to save them to be able
      // to recompute the operation on the host CPU.
      if(isFPU && state[EXECUTE_bit]) begin
	 rs1_bkp <= rs1;
	 rs2_bkp <= rs2;
	 rs3_bkp <= rs3;
      end
      
      if(
	 isFPU && 
	 (state[WAIT_ALU_OR_MEM_bit] | state[WAIT_ALU_OR_MEM_SKIP_bit]) && 
         fpmi_PC == 0
      ) begin
	 case(1'b1)
	   isFMUL :   `FPU_CHECK2("FMUL");
	   isFADD :   `FPU_CHECK2("FADD");
	   isFSUB :   `FPU_CHECK2("FSUB");
//	   isFDIV :   `FPU_CHECK2("FDIV");  // yes I know, not IEEE754 yet
//	   isFSQRT:   `FPU_CHECK1("FSQRT"); // yes I know, not IEEE754 yet
	   isFMADD:   `FPU_CHECK3("FMADD");	  
	   isFMSUB:   `FPU_CHECK3("FMSUB");	  
	   isFNMADD:  `FPU_CHECK3("FNMADD");	  
	   isFNMSUB:  `FPU_CHECK3("FNMSUB");	  
	   isFEQ:     `FPU_CHECK2("FEQ");
	   isFLT:     `FPU_CHECK2("FLT");
	   isFLE:     `FPU_CHECK2("FLE");
	   isFCVTWS : `FPU_CHECK1("FCVTWS"); 
	   isFCVTWUS: `FPU_CHECK1("FCVTWUS");
	   isFCVTSW : `FPU_CHECK1("FCVTSW"); 
	   isFCVTSWU: `FPU_CHECK1("FCVTSWU"); 
	   isFMIN:    `FPU_CHECK2("FMIN");
	   isFMAX:    `FPU_CHECK2("FMAX");
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
      (isFPU               ? fpuOut               : 32'b0) |  // FPU
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
   localparam DECOMPRESS_GETREGS_bit   = 2;   
   localparam EXECUTE_bit              = 3;
   localparam WAIT_ALU_OR_MEM_bit      = 4;
   localparam WAIT_ALU_OR_MEM_SKIP_bit = 5;

   localparam NB_STATES                = 6;

   localparam FETCH_INSTR          = 1 << FETCH_INSTR_bit;
   localparam WAIT_INSTR           = 1 << WAIT_INSTR_bit;
   localparam DECOMPRESS_GETREGS   = 1 << DECOMPRESS_GETREGS_bit;   
   localparam EXECUTE              = 1 << EXECUTE_bit;
   localparam WAIT_ALU_OR_MEM      = 1 << WAIT_ALU_OR_MEM_bit;
   localparam WAIT_ALU_OR_MEM_SKIP = 1 << WAIT_ALU_OR_MEM_SKIP_bit;

   (* onehot *)
   reg [NB_STATES-1:0] state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.

   // register write-back enable.
   wire writeBack = ~(isBranch | isStore ) & !fpuBusy & (
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

   wire needToWait = isLoad | 
                    (isStore & `NRV_IS_IO_ADDR(mem_addr)) | 
                     isDivide | 
                     isFPU;  

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
		 // Registers are fetched at the same time, in the
		 // FPU's always block.
		 instr  <= &raw_instr[1:0] ? raw_instr[31:2] 
                                           : decompressed[31:2];
		 long_instr <= &raw_instr[1:0];

		 // Long opcode, unaligned, first part fetched, 
		 // happens in non-linear code
		 if (current_unaligned_long & ~fetch_second_half) begin
                    fetch_second_half <= 1;
                    state <= FETCH_INSTR;
		 end else begin
                    fetch_second_half <= 0;
                    state <= &raw_instr[1:0] ? EXECUTE : DECOMPRESS_GETREGS;
		 end
              end
           end

           state[DECOMPRESS_GETREGS_bit]: begin
	      // All the registers are fetched in FPU's always block.
	      state <= EXECUTE;
	   end
	   
           state[EXECUTE_bit]: begin
              if (interrupt) begin
		 PC     <= mtvec;
		 mepc   <= PC_new;
		 mcause <= 1;
		 state  <= needToWait ? WAIT_ALU_OR_MEM : FETCH_INSTR;
              end else begin
		 // Unaligned load/store not implemented yet
		 // (the norm supposes that FLW and FSW can handle them)
		 `ASSERT(
                     !((isLoad|isStore) && instr[2] && |loadstore_addr[1:0]), 
		     ("PC=%x UNALIGNED FLW/FSW",PC)
                 );
		 
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

      // Four compressed RV32F load/store instructions
      16'b011_???_???_??_???_00 : d = {          lwswImm,            rch, 3'b010,                 rcl, 7'b00001_11} ; // c.flw       -->  flw   rd', offset[6:2](rs1')
      16'b111_???_???_??_???_00 : d = {    lwswImm[11:5],       rcl, rch, 3'b010,        lwswImm[4:0], 7'b01001_11} ; // c.fsw       -->  fsw   rs2', offset[6:2](rs1')
      16'b011__?_?????_?????_10 : d = {           lwspImm,            x2, 3'b010,                 rwh, 7'b00001_11} ; // c.flwsp     -->  flw   rd, offset[7:2](x2)
      16'b111__?_?????_?????_10 : d = {     swspImm[11:5],      rwl,  x2, 3'b010,        swspImm[4:0], 7'b01001_11} ; // c.fswsp     -->  fsw   rs2, offset[7:2](x2)
      

//      default:                    d =                                                                       unknown ; // Unknown opcode
     default: d = 32'bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX;
   endcase
endmodule

/*****************************************************************************/
