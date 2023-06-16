/******************************************************************************/
// FemtoRV32, a collection of minimalistic RISC-V RV32 cores.
//
// PetitBateau (make it float): a simple single-precision RISC-V FPU
//   Mission statement: achieve a good area/performance ratio, by
//   implementing a full-precision FMA (48 bits), and micro-programmed
//   Newton-Raphson for FDIV and FSQRT (that reuse the FMA).
// 
// Rounding works as follows:
// - all subnormals are flushed to zero
// - FADD, FSUB, FMUL, FMADD, FMSUB, FNMADD, FNMSUB: IEEE754 round to zero
// - FDIV and FSQRT do not have correct rounding
//   if PRECISE_DIV is set (default), then FDIV rounding is validated in 
//      tinyraytracer test. Complete proof remains to be done
//
// [TODO] add FPU CSR (and instret for perf stat)]
// [TODO] correct IEEE754 round to zero for FDIV and FSQRT
// [TODO] support IEEE754 denormals
// [TODO] NaNs propagation and infinity
// [TODO] support all IEEE754 rounding modes
//
// Bruno Levy, 2021
/******************************************************************************/

// TODO: instead of mux between A,B,C and FMA, make FMA always compute
//       A*B+C and mux rs1,rs2,rs3,1.0,0.0 to A,B,C based on instr (mux
//       will be more complicated but will probably reduce overall
//       critical path) ?
// TODO: there are too many different paths between the internal registers,
//       maybe micro-instructions could be redesigned with this in mind.
//       A could be the MSBs of X, avoiding all MV_A_X instructions.
// TODO: the necessity to copy rs1 in E without flushing denormals for
//       the int-to-fp instructions is unelegant.

// Include guard for LiteX
`ifndef PETITBATEAU_INCLUDED
`define PETITBATEAU_INCLUDED

// Check condition and display message in simulation
`ifdef BENCH
 `define ASSERT(cond,msg) if(!(cond)) $display msg
 `define ASSERT_NOT_REACHED(msg) $display msg
`else
 `define ASSERT(cond,msg)
 `define ASSERT_NOT_REACHED(msg)
`endif

module PetitBateau(
   input 	     clk,
   input 	     wr,    // write strobe, starts computation
   input [31:2]      instr, // current riscv instruction		   

   // operands		   
   input [31:0]      rs1,
   input [31:0]      rs2,
   input [31:0]      rs3,

   // outputs		   
   output 	 busy,
   output [31:0] out 	
);

   // Set to 1 for higher-precision FDIV (costs 30 additional cycles per FDIV)
   parameter PRECISE_DIV = 1;

   
   // Uncomment the line below to emulate all FPU instructions in Verilator
   // (useful to test instruction decoder and implementations of micro-instr
   // in C++). See SIM/FPU_funcs.{h,cpp}
//`define FPU_EMUL

   // Two high-resolution registers for the FMA, that computes X+Y
   // Register X has the accumulator / shifters / leading zero counter
   // Normalized if first bit set is bit 47
   // Represented number is +/- frac * 2^(exp-127-47)
   
   reg X_sign; reg signed [8:0] X_exp; reg signed [49:0] X_frac;
   reg Y_sign; reg signed [8:0] Y_exp; reg signed [49:0] Y_frac;
   
   // FPU output = 32 MSBs of X register (see below)
   // A macro to easily write to it (`X <= ...),
   // used when FPU output is an integer.
   `define X {X_sign, X_exp[7:0], X_frac[46:24]}
   assign out = `X;
   
   // Five single-precision floating-point registers for internal use.
   // A,B,C are wired to the FMA that computes either A*B+C or A+B
   // D,E are temporaries used by FDIV and FSQRT
   // Following IEEE754, represented number is +/- frac * 2^(exp-127-23)
   // (127: bias  23: position of first bit set for normalized numbers)
   reg A_sign; reg [7:0] A_exp; reg [23:0] A_frac;
   reg B_sign; reg [7:0] B_exp; reg [23:0] B_frac;
   reg C_sign; reg [7:0] C_exp; reg [23:0] C_frac;
   reg D_sign; reg [7:0] D_exp; reg [23:0] D_frac;
   reg E_sign; reg [7:0] E_exp; reg [23:0] E_frac;
   
   /*************************************************************************/

   // Load a 32-bit value in RD
   // RD:  one of A,B,C,D,E
   // VAL: a 32-bit value
   `define FP_LD32(RD,VAL)         \
         {RD``_sign, RD``_exp, RD``_frac[22:0]} <= VAL; RD``_frac[23] <= 1'b1
	 
   // Load floating point value in RD by sign, exponent, fraction
   // RD: one of A,B,C,D,E
   // sign: 1'b1 (-) or 1'b0 (+)
   // exp: 8-bits, biased exponent
   // frac: 24-bit fraction
   `define FP_LD(RD,sign,eexp,frac) \
         {RD``_sign, RD``_exp, RD``_frac} <= {sign,eexp,frac}
	 
   // RD <= RS
   // RD,RS: one of A,B,C,D,E
   `define FP_MV(RD,RS)            \
         {RD``_sign, RD``_exp, RD``_frac} <= {RS``_sign, RS``_exp, RS``_frac}

   /** FPU micro-instructions and ROM ****************************************/

   
   localparam FPMI_READY           = 0; 
   localparam FPMI_LOAD_XY         = 1;   // X <- A; Y <- B
   localparam FPMI_LOAD_XY_MUL     = 2;   // X <- norm(A*B); Y <- C
   localparam FPMI_ADD_SWAP        = 3;   // if |X|>|Y| swap(X,Y);
                                          // if sign(X) != sign(Y) X <- -X
   localparam FPMI_ADD_SHIFT       = 4;   // shift X to match Y exponent
   localparam FPMI_ADD_ADD         = 5;   // X <- X + Y   
   localparam FPMI_ADD_NORM        = 6;   // X <- norm(X) (after ADD_ADD)
   
   localparam FPMI_CMP             = 7;   // X <- test X,Y (FEQ,FLE,FLT)

   localparam FPMI_MV_A_X          =  8;  // A <- X
   localparam FPMI_MV_B_D          =  9;  // B <- D
   localparam FPMI_MV_B_NH_D       = 10;  // B <- -0.5*|D|
   localparam FPMI_MV_B_E          = 11;  // B <- E
   localparam FPMI_MV_C_A          = 12;  // C <- A
   localparam FPMI_MV_E_X          = 13;  // E <- X

   localparam FPMI_FRCP_PROLOG     = 14;  // init reciprocal (1/x) 
   localparam FPMI_FRCP_ITER1      = 15;  // iteration for reciprocal
   localparam FPMI_FRCP_ITER2      = 16;  // iteration for reciprocal   
   localparam FPMI_FRCP_EPILOG     = 17;  // epilog for reciprocal
   localparam FPMI_FDIV_EPILOG     = 18;  // epilog for fdiv IEEE-754 rounding
   
   localparam FPMI_FRSQRT_PROLOG   = 19;  // init recipr sqr root (1/sqrt(x))
   
   localparam FPMI_FP_TO_INT       = 20;  // fpuOut <- fpoint_to_int(A)
   localparam FPMI_INT_TO_FP       = 21;  // X <- int_to_fpoint(X)
   localparam FPMI_MIN_MAX         = 22;  // fpuOut <- min/max(X,Y) 

   localparam FPMI_LOAD_Y_ROUND    = 23;  // Y <- round to nearest
   
   localparam FPMI_NB              = 24;

   // Instruction exit flag (if set in current micro-instr, exit microprogram)
   localparam FPMI_EXIT_FLAG_bit   = 1+$clog2(FPMI_NB);
   localparam FPMI_EXIT_FLAG       = 1 << FPMI_EXIT_FLAG_bit;
   
   reg [6:0] 	             fpmi_PC;    // current micro-instruction pointer
   reg [1+$clog2(FPMI_NB):0] fpmi_instr; // current micro-instruction

   // current micro-instruction as 1-hot: fpmi_instr == NNN <=> fpmi_is[NNN]
   (* onehot *)
   wire [FPMI_NB-1:0] fpmi_is = 1 << fpmi_instr[$clog2(FPMI_NB):0]; 
   initial fpmi_PC = 0;
   assign busy = !fpmi_is[FPMI_READY];

   // Generate a micro-instructions in ROM 
   task fpmi_gen; input [6:0] instr; begin
      fpmi_ROM[I] = instr;
      I = I + 1;
   end endtask   

   // Generate a FMA sequence in ROM.
   // Use fpmi_gen_fma(0) in the middle of a micro-program
   // Use fpmi_gen_fma(FPMI_EXIT_FLAG) if last instruction of micro-program
   task fpmi_gen_fma; input [6:0] flags; begin
      fpmi_gen(FPMI_LOAD_XY_MUL);      // X <- norm(A*B), Y <- C  
      fpmi_gen(FPMI_ADD_SWAP);         // if(|X| > |Y|) swap(X,Y) (and sgn)
      fpmi_gen(FPMI_ADD_SHIFT);        // shift X according to Y exp
      fpmi_gen(FPMI_ADD_ADD);          // X <- X + Y
      fpmi_gen(FPMI_ADD_NORM | flags); // X <- normalize(X)
   end endtask
   
   integer I;    // current ROM location in initialization
   integer iter; // iteration variable for generate Newton-Raphson (FDIV,FSQRT)
   localparam FPMI_ROM_SIZE=82 + (12 + 18)*PRECISE_DIV; 
   reg [1+$clog2(FPMI_NB):0] fpmi_ROM[0:FPMI_ROM_SIZE-1];
   
   // Microprograms start addresses
   // Programatically determined when generating the ROM ('initial' block below)
   integer FPMPROG_CMP, FPMPROG_ADD, FPMPROG_MUL, FPMPROG_MADD, FPMPROG_DIV;
   integer FPMPROG_FP_TO_INT, FPMPROG_INT_TO_FP, FPMPROG_SQRT, FPMPROG_MIN_MAX;

   // Start the definition of a microprogram (determines start address)
   `define FPMPROG_BEGIN(prg) prg = I

   // Ends the definition of a microprogram (displays stats in Verilator)
   `ifdef BENCH
    `define FPMPROG_END(prg) \
        $display("#  %3d microinstructions used by %d:%s",I-prg,prg,`"prg`")
   `else
    `define FPMPROG_END(prg) 
   `endif

   /******************** Generate microprograms in ROM **********************/
   initial begin

   `ifdef BENCH
      $display("#  Generating FPMI ROM...");
   `endif
      I = 0;
      fpmi_gen(FPMI_READY | FPMI_EXIT_FLAG);

      // ******************** FLT, FLE, FEQ *********************************
      `FPMPROG_BEGIN(FPMPROG_CMP);
      fpmi_gen(FPMI_LOAD_XY);              // X <- A, Y <- B
      fpmi_gen(FPMI_CMP | FPMI_EXIT_FLAG); // X <- compare(X,Y)
      `FPMPROG_END(FPMPROG_CMP);
      
      // ******************** FADD, FSUB ************************************
      `FPMPROG_BEGIN(FPMPROG_ADD);
      fpmi_gen(FPMI_LOAD_XY);               // X <- A, Y <- B
      fpmi_gen(FPMI_ADD_SWAP);              // if(|X| > |Y|) swap(X,Y) (,sgn)
      fpmi_gen(FPMI_ADD_SHIFT);             // shift X according to Y exp
      fpmi_gen(FPMI_ADD_ADD);               // X <- X + Y
      fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG); // X <- normalize(X)
      `FPMPROG_END(FPMPROG_ADD);
      
      // ******************** FMUL ******************************************
      `FPMPROG_BEGIN(FPMPROG_MUL);
      fpmi_gen(FPMI_LOAD_XY_MUL | FPMI_EXIT_FLAG); // X <- A*B
      `FPMPROG_END(FPMPROG_MUL);

      // ******************** FMADD, FMSUB, FNMADD, FNMSUB ******************
      `FPMPROG_BEGIN(FPMPROG_MADD);
      fpmi_gen_fma(FPMI_EXIT_FLAG); // X <- A*B+C (5 cycles)
      `FPMPROG_END(FPMPROG_MADD);      

      // ******************** FDIV ******************************************
      // https://en.wikipedia.org/wiki/Division_algorithm
      // https://stackoverflow.com/questions/24792966/
      // error-using-newton-raphson-iteration-method-for-
      // floating-point-division
      //
      `FPMPROG_BEGIN(FPMPROG_DIV);      
      // D' = denominator (rs2) normalized between [0.5,1] (set exp to 126)
      fpmi_gen(FPMI_FRCP_PROLOG); // D<-A; E<-B; A<-(-D'); B<-32/17; C<-48/17
      fpmi_gen_fma(0);            // X <- A*B+C (= -D'*32/17 + 48/17)
      for(iter=0; iter<3; iter=iter+1) begin
	 if(PRECISE_DIV) begin
	    // X <- X + X*(1-D'*X)
	    // (slower more precise iter, but not IEEE754 compliant yet...)
	    fpmi_gen(FPMI_FRCP_ITER1); // A <- -D'; B <- X; C <- 1.0f
	    fpmi_gen_fma(0);           // X <- A*B+C (5 cycles)
	    fpmi_gen(FPMI_FRCP_ITER2); // A <- X; C <- B
	    fpmi_gen_fma(0);           // X <- A*B+C (5 cycles)
	 end else begin
	    //  X <- X * (-X*D' + 2)
	    // (faster but less precise)
	    fpmi_gen(FPMI_FRCP_ITER1);  // A <- -D'; B <- X; C <- 2.0f    
	    fpmi_gen_fma(0);            // X <- A*B+C (5 cycles)
	    fpmi_gen(FPMI_MV_A_X);      // A <- X
	    fpmi_gen(FPMI_LOAD_XY_MUL); // X <- A*B; Y <- C
	 end
      end 
      if(PRECISE_DIV) begin             // round X to nearest
	 fpmi_gen(FPMI_LOAD_Y_ROUND);
	 fpmi_gen(FPMI_ADD_ADD);
	 fpmi_gen(FPMI_ADD_NORM);
      end      
      fpmi_gen(FPMI_FRCP_EPILOG); // A <- (E_sign,frcp_exp,X_frac); B <- D
      if(PRECISE_DIV) begin // error correction
	 fpmi_gen(FPMI_LOAD_XY_MUL); // X <- A*B
	 fpmi_gen(FPMI_FDIV_EPILOG); // B <- -E; C <- D; D <- A
	 fpmi_gen(FPMI_MV_A_X);
	 fpmi_gen_fma(0);
	 fpmi_gen(FPMI_MV_C_A);
	 fpmi_gen(FPMI_MV_B_D);
	 fpmi_gen(FPMI_MV_A_X);
	 fpmi_gen_fma(FPMI_EXIT_FLAG);
      end else begin
	 fpmi_gen(FPMI_LOAD_XY_MUL | FPMI_EXIT_FLAG); // X <- A*B
      end
      `FPMPROG_END(FPMPROG_DIV);      
      
      // ******************** FCVT.W.S, FCVT.WU.S ***************************
      `FPMPROG_BEGIN(FPMPROG_FP_TO_INT);
      fpmi_gen(FPMI_LOAD_XY);
      fpmi_gen(FPMI_FP_TO_INT | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_FP_TO_INT);      
      
      // ******************** FCVT.S.W, FCVT.S.WU ***************************
      `FPMPROG_BEGIN(FPMPROG_INT_TO_FP); // Compute A+0 (use CLZ plugged on X)
      fpmi_gen(FPMI_INT_TO_FP);                 // X <- 0; Y <- A
      fpmi_gen(FPMI_ADD_ADD);                   // X <- X + Y
      fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG); // X <- normalize(X)
      `FPMPROG_END(FPMPROG_INT_TO_FP);
      
      // ******************** FSQRT *****************************************
      // Using Doom's fast inverse square root algorithm:
      // https://en.wikipedia.org/wiki/Fast_inverse_square_root
      // http://www.lomont.org/papers/2003/InvSqrt.pdf
      // TODO: IEEE754-compliant version
      // See https://t.co/V1SWQ6N6xD?amp=1 (Method of Switching Constants)
      // See simple effective fast inverse square root with two magic 
      // constants.
      //
      `FPMPROG_BEGIN(FPMPROG_SQRT);
      // D<-rs1; E,A,B<-(doom_magic - (A >> 1)); C<-3/2
      fpmi_gen(FPMI_FRSQRT_PROLOG);
      for(iter=0; iter<2; iter=iter+1) begin
	 // X <- X * (3/2 - (0.5*rs1*X*X))      	 
	 fpmi_gen(FPMI_LOAD_XY_MUL);  // X <- A*B; Y <- C
	 fpmi_gen(FPMI_MV_A_X);       // A <- X
         fpmi_gen(FPMI_MV_B_NH_D);    // B <- -0.5*|D|
	 fpmi_gen_fma(0);             // X <- A*B+C
	 fpmi_gen(FPMI_MV_A_X);       // A <- X
	 fpmi_gen(FPMI_MV_B_E);       // B <- E
	 fpmi_gen(FPMI_LOAD_XY_MUL);  // X <- A*B; Y <- C
	 if(iter==0) begin
	    fpmi_gen(FPMI_MV_E_X);    // E <- X
	    fpmi_gen(FPMI_MV_A_X);    // A <- X
	    fpmi_gen(FPMI_MV_B_E);    // B <- E
	 end
      end // X contains 1/sqrt(rs1), now compute rs1*X to get sqrt(rs1)
      fpmi_gen(FPMI_MV_A_X);                       // A <- X
      fpmi_gen(FPMI_MV_B_D);                       // B <- D
      fpmi_gen(FPMI_LOAD_XY_MUL | FPMI_EXIT_FLAG); // X <- A*B; Y <- C
      `FPMPROG_END(FPMPROG_SQRT);
      
      // ******************** FMIN, FMAX ************************************
      `FPMPROG_BEGIN(FPMPROG_MIN_MAX);
      fpmi_gen(FPMI_LOAD_XY);
      fpmi_gen(FPMI_MIN_MAX | FPMI_EXIT_FLAG);
      `FPMPROG_END(FPMPROG_MIN_MAX);
      
`ifdef BENCH      
      $display("#  FPMI ROM max address:%d",I-1);
      $display("#  FPMI ROM size       :%d",FPMI_ROM_SIZE);      
      `ASSERT(I <= FPMI_ROM_SIZE,("!!!!!!! FPMI ROM SIZE exceeded !!!!!!!"));
`endif      
   end

`ifndef FPU_EMUL

   // determine microprogram to be called based on decoded instruction
   reg [6:0] fpmprog;
   always @(*) begin
      (* parallel_case, full_case *)
      case(1'b1)
	isFLT   | isFLE   | isFEQ               : fpmprog = FPMPROG_CMP[6:0];
	isFADD  | isFSUB                        : fpmprog = FPMPROG_ADD[6:0];
	isFMUL                                  : fpmprog = FPMPROG_MUL[6:0];
	isFMADD | isFMSUB | isFNMADD | isFNMSUB : fpmprog = FPMPROG_MADD[6:0];
	isFDIV                                  : fpmprog = FPMPROG_DIV[6:0];
	isFSQRT                                 : fpmprog = FPMPROG_SQRT[6:0];
	isFCVTWS | isFCVTWUS  : fpmprog = FPMPROG_FP_TO_INT[6:0];
	isFCVTSW | isFCVTSWU  : fpmprog = FPMPROG_INT_TO_FP[6:0];
	isFMIN   | isFMAX     : fpmprog = FPMPROG_MIN_MAX[6:0];
	default               : fpmprog = 0;
      endcase
   end
   
   // next micro-instruction program counter
   wire [6:0] fpmi_PC_next = 
               wr                             ? fpmprog   :
	       fpmi_instr[FPMI_EXIT_FLAG_bit] ? 0         : 
                                                fpmi_PC+1 ;
   always @(posedge clk) begin
      fpmi_PC <= fpmi_PC_next;
      fpmi_instr <= fpmi_ROM[fpmi_PC_next];
   end
   

   always @(posedge clk) begin
      if(wr) begin
         // Denormals are flushed to zero
         `FP_LD(A, rs1[31], rs1[30:23], (|rs1[30:23]?{1'b1,rs1[22:0]}:24'b0));
         `FP_LD(B, rs2[31], rs2[30:23], (|rs2[30:23]?{1'b1,rs2[22:0]}:24'b0));
         `FP_LD(C, rs3[31], rs3[30:23], (|rs3[30:23]?{1'b1,rs3[22:0]}:24'b0));

	 // Backup rs1 in E without flushing to zero (for int2fp instructions)
         `FP_LD32(E, rs1);	 

         // Single-cycle instructions
	 (* parallel_case *)
	 case(1'b1)
	   isFSGNJ           : `X <= {         rs2[31], rs1[30:0]};
	   isFSGNJN          : `X <= {        !rs2[31], rs1[30:0]};
	   isFSGNJX          : `X <= { rs1[31]^rs2[31], rs1[30:0]};
	   isFCLASS          : `X <= fclass;
           isFMVXW | isFMVWX : `X <= rs1;
	 endcase 
      end else if(busy) begin 

	 // Implementation of the micro-instructions	 
	 (* parallel_case *)	 
	 case(1'b1)
	   // X <- A ; Y <- B
	   fpmi_is[FPMI_LOAD_XY]: begin
	      X_sign <= A_sign;
	      X_frac <= {2'b0, A_frac, 24'd0};
	      X_exp  <= {1'b0, A_exp}; 
	      Y_sign <= B_sign ^ isFSUB;
	      Y_frac <= {2'b0, B_frac, 24'd0};
	      Y_exp  <= {1'b0, B_exp}; 
	   end

	   // X <- (+/-) normalize(A*B);  Y <- (+/-)C
	   fpmi_is[FPMI_LOAD_XY_MUL]: begin
	      X_sign <= A_sign ^ B_sign ^ (isFNMSUB | isFNMADD);
	      X_frac <= prod_Z ? 0 :  
                          (prod_frac[47] ? prod_frac : {prod_frac[48:0],1'b0}); 
	      X_exp  <= prod_Z ? 0 : prod_exp_norm;
	      Y_sign <= C_sign ^ (isFMSUB | isFNMADD);
	      Y_frac <= {2'b0, C_frac, 24'd0};
	      Y_exp  <= {1'b0, C_exp};
	   end

	   // if(|X| > |Y|) swap(X,Y)
	   // if X_sign != Y_sign X <- -X
	   // We always *add*, but replace X_frac with -X_frac if the
	   // sign of the operands differ, THEN we shift (signed shift). In
	   // this way, rounding is correct, even when subtracting a
	   // low magnitude numner from a large magnitude one.
	   fpmi_is[FPMI_ADD_SWAP]: begin
	      if(fabsY_LT_fabsX) begin
		 X_frac <= (X_sign ^ Y_sign) ? -Y_frac : Y_frac; 
		 Y_frac <= X_frac;
		 X_exp  <= Y_exp;  Y_exp  <= X_exp;
		 X_sign <= Y_sign; Y_sign <= X_sign;
	      end else if(X_sign ^ Y_sign) begin
		 X_frac <= -X_frac;
	      end
	   end

	   // shift A in order to make it match B exponent
	   fpmi_is[FPMI_ADD_SHIFT]: begin
	      `ASSERT(!fabsY_LT_fabsX, ("ADD_SHIFT: incorrect order"));
	      X_frac <= X_frac >>> exp_diff; // note the signed shift !
	      X_exp <= Y_exp;
	   end

	   // A <- A (+/-) B
	   fpmi_is[FPMI_ADD_ADD]: begin
	      X_frac      <= frac_sum[49:0];
	      X_sign      <= Y_sign;
	      // normalization left shamt = 47 - first_bit_set = clz - 16
	      norm_lshamt <= frac_sum_clz - 16;
	      // Exponent of X once normalized = X_exp + first_bit_set - 47
	      //                 = X_exp + 63 - clz - 47 = X_exp + 16 - clz
	      X_exp_norm <= X_exp + 16 - {3'b000,frac_sum_clz};
	   end

	   // X <- normalize(X) (after ADD_ADD -> norm_lshamt and A_exp_norm)
	   fpmi_is[FPMI_ADD_NORM]: begin
	      if(X_exp_norm <= 0 || (X_frac == 0)) begin
		 X_frac <= 0;
		 X_exp <= 0;
	      end else begin
		 X_frac <= X_frac[48] ? (X_frac >> 1) : X_frac << norm_lshamt;
		 X_exp  <= X_exp_norm;
	      end
	   end

	   fpmi_is[FPMI_LOAD_Y_ROUND]: begin
	      Y_sign <= X_sign;
	      Y_exp  <= X_exp;
	      Y_frac <= X_frac[23] ? (1 << 24) : 50'd0; 
	   end
	   
	   // X <- result of comparison between X and Y
	   fpmi_is[FPMI_CMP]: begin
	      `X <= { 31'b0, 
			    isFLT && X_LT_Y || 
			    isFLE && X_LE_Y || 
			    isFEQ && X_EQ_Y
                          };
	   end

	   fpmi_is[FPMI_MV_B_D] : `FP_MV(B,D);
	   fpmi_is[FPMI_MV_B_E] : `FP_MV(B,E);
	   fpmi_is[FPMI_MV_A_X] : `FP_LD(A,X_sign,X_exp[7:0],X_frac[47:24]);
	   fpmi_is[FPMI_MV_C_A] : `FP_MV(C,A);
	   fpmi_is[FPMI_MV_E_X] : `FP_LD(E,X_sign,X_exp[7:0],X_frac[47:24]);
	   
	   // B <= -|D| / 2.0
	   fpmi_is[FPMI_MV_B_NH_D]: 
	                {B_sign, B_exp, B_frac} <= {1'b1,D_exp-8'd1,D_frac};

	   fpmi_is[FPMI_FRCP_PROLOG]: begin
	      `FP_MV(D,A);
	      `FP_MV(E,B);
	       // A <= -D', that is, -(B normalized in [0.5,1])	      
	      `FP_LD(A,1'b1,8'd126, B_frac); 
	      `FP_LD32(B, 32'h3FF0F0F1); // 32/17
	      `FP_LD32(C, 32'h4034B4B5); // 48/17
	   end
	   
	   fpmi_is[FPMI_FRCP_ITER1]: begin
	      `FP_LD(A,1'b1,8'd126, E_frac);             // A <= -D'
	      `FP_LD(B,X_sign,X_exp[7:0],X_frac[47:24]); // B <= X
	       //                           1.0            2.0
	      `FP_LD32(C, PRECISE_DIV ? 32'h3f800000 : 32'h40000000); 
	   end

	   // This one is used only if PRECISE_DIV is set
	   fpmi_is[FPMI_FRCP_ITER2]: begin
	      `FP_LD(A,X_sign,X_exp[7:0],X_frac[47:24]); // A <= X
	      `FP_MV(C,B);
	   end
	   
	   fpmi_is[FPMI_FRCP_EPILOG]: begin
	      `FP_LD(A,E_sign,frcp_exp[7:0],X_frac[47:24]);
	      `FP_MV(B,D);
	   end

	   // This one is used only if PRECISE_DIV is set
	   fpmi_is[FPMI_FDIV_EPILOG]: begin
	      `FP_LD(B,!E_sign, E_exp, E_frac); // B <= -E
	      `FP_MV(C,D);
	      `FP_MV(D,A);
	   end
	   
	   fpmi_is[FPMI_FRSQRT_PROLOG]: begin
	      `FP_LD32(D, rs1);
	      `FP_LD32(E, rsqrt_doom_magic);
	      `FP_LD32(A, rsqrt_doom_magic);
	      `FP_LD32(B, rsqrt_doom_magic);
	      `FP_LD32(C, 32'h3fc00000); // 1.5
	   end
	   
	   fpmi_is[FPMI_FP_TO_INT]: begin
	      // TODO: check overflow
	      `X <= 
               (isFCVTWUS | !X_sign) ? X_fcvt_ftoi_shifted 
                                     : -$signed(X_fcvt_ftoi_shifted);
	   end

	   fpmi_is[FPMI_INT_TO_FP]: begin
	      // TODO: rounding
	      // We do a fake addition with zero, to prepare normalization
	      // (uses CLZ plugged on the adder).
	      X_frac <= 0;
	      // 127+23: standard exponent bias
	      // +6 because it is bit 29 of rs1 that overwrites 
	      //    bit 47 of A_frac, instead of bit 23 (and 29-23 = 6).
	      X_exp  <= 127+23+6;
	      Y_frac <= 
	         (isFCVTSWU | !E_sign) ? {E_sign, E_exp, E_frac[22:0], 18'd0}
                           : {-$signed({E_sign, E_exp, E_frac[22:0]}), 18'd0};
	      Y_sign <= isFCVTSW & E_sign;
	   end 
	   
	   fpmi_is[FPMI_MIN_MAX]: begin
	      `X <=  (X_LT_Y ^ isFMAX)
		                 ? {X_sign, X_exp[7:0], X_frac[46:24]}
	 	                 : {Y_sign, Y_exp[7:0], Y_frac[46:24]};
	   end
	 endcase 
      end
   end
`endif   

   // Some circuitry used by the FPU micro-instructions:

   // ******************* Comparisons ******************************************
   // Exponent adder
   wire signed [8:0]  exp_sum   = Y_exp + X_exp;
   wire signed [8:0]  exp_diff  = Y_exp - X_exp;
   
   wire expX_EQ_expY   = (exp_diff  == 0);
   wire fracX_EQ_fracY = (frac_diff == 0);
   wire fabsX_EQ_fabsY = (expX_EQ_expY && fracX_EQ_fracY);
   wire fabsX_LT_fabsY = (!exp_diff[8] && !expX_EQ_expY) || 
                           (expX_EQ_expY && !fracX_EQ_fracY && !frac_diff[50]);

   wire fabsX_LE_fabsY = (!exp_diff[8] && !expX_EQ_expY) || 
                                              (expX_EQ_expY && !frac_diff[50]);
   
   wire fabsY_LT_fabsX = exp_diff[8] || (expX_EQ_expY && frac_diff[50]);

   wire fabsY_LE_fabsX = exp_diff[8] || 
                           (expX_EQ_expY && (frac_diff[50] || fracX_EQ_fracY));

   wire X_LT_Y = X_sign && !Y_sign ||
	         X_sign &&  Y_sign && fabsY_LT_fabsX ||
 		!X_sign && !Y_sign && fabsX_LT_fabsY ;

   wire X_LE_Y = X_sign && !Y_sign ||
		 X_sign &&  Y_sign && fabsY_LE_fabsX ||
 	        !X_sign && !Y_sign && fabsX_LE_fabsY ;
   
   wire X_EQ_Y = fabsX_EQ_fabsY && (X_sign == Y_sign);

   // ****************** Addition, subtraction *********************************
   wire signed [50:0] frac_sum  = Y_frac + X_frac;
   wire signed [50:0] frac_diff = Y_frac - X_frac;

   // ****************** Product ***********************************************
   wire [49:0] prod_frac = A_frac * B_frac; // TODO: check overflows

   // exponent of product, once normalized
   // (obtained by writing expression of product and inspecting exponent)
   // Two cases: first bit set = 47 or 46 (only possible cases with normals)
   wire signed [8:0] prod_exp_norm = A_exp+B_exp-127+{7'b0,prod_frac[47]};

   // detect null product and underflows (all denormals are flushed to zero)
   wire prod_Z = (prod_exp_norm <= 0) || !(|prod_frac[47:46]);

   // ****************** Normalization *****************************************
   // Count leading zeroes in A+B
   // Note1: CLZ only work with power of two width (hence 13'b0 padding).
   // Note2: first bit set = 63 - CLZ (of course !)
   wire [5:0] 	              frac_sum_clz;
   CLZ clz2({13'b0,frac_sum}, frac_sum_clz);
   reg [5:0] 		      norm_lshamt; // shift amount for ADD normalization

   // Exponent of A once normalized = X_exp + first_bit_set - 47
   //                               = X_exp + 63 - clz - 47 = X_exp + 16 - clz
   // X_exp_norm <= X_exp + 16 - {3'b000,A_clz};
   reg signed [8:0] X_exp_norm;

   // ****************** Reciprocal (1/x), used by FDIV ************************
   // Exponent for reciprocal (1/x)
   // Initial value of x kept in E.
   wire signed [8:0]  frcp_exp  = 9'd126 + X_exp - $signed({1'b0, E_exp});

   // ****************** Reciprocal square root (1/sqrt(x)) ********************
   // https://en.wikipedia.org/wiki/Fast_inverse_square_root
   wire [31:0] rsqrt_doom_magic = 32'h5f3759df - {1'b0,A_exp, A_frac[22:1]};

   // ****************** Float to Integer conversion ***************************
   // -127-23 is standard exponent bias
   // -6 because it is bit 29 of X that corresponds to bit 47 of X_frac,
   //    instead of bit 23 (and 23-29 = -6).
   wire signed [8:0]  fcvt_ftoi_shift = A_exp - 9'd127 - 9'd23 - 9'd6; 
   wire signed [8:0]  neg_fcvt_ftoi_shift = -fcvt_ftoi_shift;
   
   wire [31:0] 	X_fcvt_ftoi_shifted =  fcvt_ftoi_shift[8] ? // R or L shift
                        (|neg_fcvt_ftoi_shift[8:5]  ?  0 :  // underflow
                     ({X_frac[49:18]} >> neg_fcvt_ftoi_shift[4:0])) : 
                     ({X_frac[49:18]} << fcvt_ftoi_shift[4:0]);
   
   // ******************* Classification ***************************************

   wire rs1_exp_Z   = (rs1[30:23] == 0  );
   wire rs1_exp_255 = (rs1[30:23] == 255);
   wire rs1_frac_Z  = (rs1[22:0]  == 0  );
   
   wire [31:0] fclass = {
      22'b0,				    
      rs1_exp_255 &  rs1[22],                         // 9: quiet NaN
      rs1_exp_255 & !rs1[22] & (|rs1[21:0]),          // 8: sig   NaN
              !rs1[31] &  rs1_exp_255 & rs1_frac_Z,   // 7: +infinity
              !rs1[31] & !rs1_exp_Z   & !rs1_exp_255, // 6: +normal
              !rs1[31] &  rs1_exp_Z   & !rs1_frac_Z,  // 5: +subnormal
              !rs1[31] &  rs1_exp_Z   & rs1_frac_Z,   // 4: +0  
               rs1[31] &  rs1_exp_Z   & rs1_frac_Z,   // 3: -0
               rs1[31] &  rs1_exp_Z   & !rs1_frac_Z,  // 2: -subnormal
               rs1[31] & !rs1_exp_Z   & !rs1_exp_255, // 1: -normal
               rs1[31] &  rs1_exp_255 & rs1_frac_Z    // 0: -infinity
   };

   /************************************************************************/
   
   // RV32F instruction decoder
   // See table p133 (RV32G instruction listings)
   // Notes:
   //  - FLW/FSW handled by LOAD/STORE in femtorv32 (instr[2] set if FLW/FSW)
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
   //        (here, it is done by the FPMI_LOAD_XY_MUL micro instruction).

   reg isFMADD, isFMSUB, isFNMSUB, isFNMADD;
   reg isFADD, isFSUB, isFMUL, isFDIV, isFSQRT;
   reg isFSGNJ, isFSGNJN, isFSGNJX;
   reg isFMIN, isFMAX;
   reg isFEQ, isFLT, isFLE;
   reg isFCLASS, isFCVTWS, isFCVTWUS;
   reg isFCVTSW, isFCVTSWU;
   reg isFMVXW, isFMVWX;

   always @(*) begin
      isFMADD   = (instr[4:2] == 3'b000); // rd <-   rs1*rs2+rs3
      isFMSUB   = (instr[4:2] == 3'b001); // rd <-   rs1*rs2-rs3
      isFNMSUB  = (instr[4:2] == 3'b010); // rd <- -(rs1*rs2-rs3) 
      isFNMADD  = (instr[4:2] == 3'b011); // rd <- -(rs1*rs2+rs3) 

      isFADD    = (instr[4] && (instr[31:27] == 5'b00000));
      isFSUB    = (instr[4] && (instr[31:27] == 5'b00001));
      isFMUL    = (instr[4] && (instr[31:27] == 5'b00010));
      isFDIV    = (instr[4] && (instr[31:27] == 5'b00011));
      isFSQRT   = (instr[4] && (instr[31:27] == 5'b01011));   

      isFSGNJ  = (instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b00));
      isFSGNJN = (instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b01));
      isFSGNJX = (instr[4] && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b10));

      isFMIN    = (instr[4] && (instr[31:27] == 5'b00101) && !instr[12]);
      isFMAX    = (instr[4] && (instr[31:27] == 5'b00101) &&  instr[12]);

      isFEQ =(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b10));
      isFLT =(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b01));
      isFLE =(instr[4] && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b00));
   
      isFCLASS  = (instr[4] && (instr[31:27] == 5'b11100) &&  instr[12]); 
   
      isFCVTWS  = (instr[4] && (instr[31:27] == 5'b11000) && !instr[20]);
      isFCVTWUS = (instr[4] && (instr[31:27] == 5'b11000) &&  instr[20]);
      
      isFCVTSW  = (instr[4] && (instr[31:27] == 5'b11010) && !instr[20]);
      isFCVTSWU = (instr[4] && (instr[31:27] == 5'b11010) &&  instr[20]);
      
      isFMVXW   = (instr[4] && (instr[31:27] == 5'b11100) && !instr[12]);
      isFMVWX   = (instr[4] && (instr[31:27] == 5'b11110));
   end

`ifdef FPU_EMUL
 `define FPU_EMUL1(op) `X <= $c32(op,"(",rs1,")")
 `define FPU_EMUL2(op) `X <= $c32(op,"(",rs1,",",rs2,")")
 `define FPU_EMUL3(op) `X <= $c32(op,"(",rs1,",",rs2,",",rs3,")")
   always @(posedge clk) begin
      if(wr) begin
	 (* parallel_case *)
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
           isFMVXW | isFMVWX : `X <= rs1;
         endcase		     
      end		     
   end
`endif

/****************************************************************************/
// When doing simulations, compare the result of all operations with
// what's computed on the host CPU. 
// Note: my FDIV and FSQRT are not IEEE754 compliant (yet) ! 
// (checks commented-out for now)

`ifdef NRV_FEMTORV32_PETITBATEAU // makes sure we are in the learn-FPGA fmwk
`ifdef VERILATOR   

 `define FPU_CHECK1(op) \
       z <= $c32("CHECK_",op,"(",`X,",",rs1,")")
 `define FPU_CHECK2(op) \
       z <= $c32("CHECK_",op,"(",`X,",",rs1,",",rs2,")")
 `define FPU_CHECK3(op) \
       z <= $c32("CHECK_",op,"(",`X,",",rs1,",",rs2,",",rs3,")")
   
   reg [31:0] z;
   reg 	      active;
   
   always @(posedge clk) begin
      
      if(wr) begin
	 active  <= 1'b1;
      end
      
      if(active && !busy) begin
	 active <= 1'b0;
	 case(1'b1)
	   isFMUL :   `FPU_CHECK2("FMUL");
	   isFADD :   `FPU_CHECK2("FADD");
	   isFSUB :   `FPU_CHECK2("FSUB");
	   isFDIV :   `FPU_CHECK2("FDIV");  
	   // isFSQRT:   `FPU_CHECK1("FSQRT"); // yes I know, not IEEE754 yet
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
`endif

endmodule   
   
/**********************************************************************/

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

`endif
