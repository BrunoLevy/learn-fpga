Notes on Implementing RV32F
===========================

Let us see if we can make tinyraytracer (and other programs) faster on
FemtoRV, by implementing single-precision floating point instructions.

TL;DR: the "PetitBateau" FPU is [here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/petitbateau.v).
It does not fully respect the IEEE754 norm (it has
correct round-to-zero for FADD,FSUB,FMUL,FMADD,FMSUB,FNMADD,FNMSUB,
but not for the other operations, that is, FDIV and FSQRT). However,
it works well in practice (e.g., with tinyraytracer). 

The RV32F instruction subset
----------------------------

The RV32F instruction subset has 26 (!) instructions. We know that 
implementing them will require some work (to have something that works
almost took me the same amount of work as creating my first RV32IM core,
and it is still not fully compliant with the norm !). In terms of lines
of code, the FPU (RV32F) and the rest of the RV32IMC core both weight
around 800 lines of code (including comments and debugging code). 

Let us review the 26 instructions quickly. 
First the easy ones (+,-,/,sqrt). Here is what they do (as you have guessed !):

|instr | algo            |
|------|-----------------|
|FADD  | rd <- rs1 + rs2 |
|FSUB  | rd <- rs1 - rs2 |
|FMUL  | rd <- rs1 * rs2 |
|FDIV  | rd <- rs1 / rs2 |
|FSQRT | rd <- sqrt(rs1) |

The RV32F also introduces 32 additional 32-bit registers to store the
floating point numbers.

*Side note: There exists a different version of the instruction 
subset (Zfinx) that uses a unique register bank for integer and
floating-point registers. Can be interesting for instance to design
a minimalistic floating-point able core, used to design for instance
a GPU-like device with multiple cores.*

Then there are the FMA instructions (fused-multiply-add) that computes
rs1*rs2+rs3 in a single instruction (with different sign
combinations):

|instr  | algo                     |
|-------|--------------------------|
|FMADD  | rd <-   rs1 * rs2 + rs3  |
|FMSUB  | rd <-   rs1 * rs2 + rs3  |
|FNMADD | rd <- -(rs1 * rs2 + rs3) |
|FNMSUB | rd <- -(rs1 * rs2 + rs3) |

*Side note: there is a big catch in the official documentation: they
say FNMADD computes `-rs1*rs2-rs3` (which is true, it is an equivalent
formula as what's written in the table above, but it is misleading:
with this formula, FNMADD computes a subtraction). I spent a couple of
hours on this ! (thank you @rob-ng15 for pointing this to me, saved
the day). I think the reason it is written like that in the
documentation is that from an implementation point of view, it is
easier to change the sign of the operands when they are loaded than
the sign of the result in the end.*

There are three instructions to manipulate the sign of a floating point
number (in rs1) based on the sign of another floating point number (in
rs2):

|instr  | algo                                  |
|-------|---------------------------------------|
|FSGNJ  | rd <- abs(rs1) * sign(rs2)            |
|FSGNJN | rd <- abs(rs1) * -sign(rs2)           |
|FSGNJX | rd <- abs(rs1) * sign(rs1) * sgn(rs2) |

Instructions for min and max (no big surprise here):
|instr  | algo                               |
|-------|------------------------------------|
|FMIN   | rd <- min(rs1,rs2)                 |
|FMAX   | rd <- max(rs1,rs2)                 |

Tests (rd is an integer register):
|instr  | algo                               |
|-------|------------------------------------|
|FEQ    | rd <- (rs1==rs2) ? 1 : 0           |
|FLT    | rd <- (rs1<rs2) ? 1 : 0            |
|FLE    | rd <- (rs1<=rs2) ? 1 : 0           |

The FCLASS instruction recognizes the type of floating point number stored in rs1
(rd is an integer register):
|instr  | algo                               |
|-------|------------------------------------|
|FCLASS | rd <- classify(rs1)                |

It sets the bits of rd as follows:
| 31:10   |    9      |    8     |   7    |    6    |     5      |  4 |  3 |   2        | 1       | 0     |
|---------|-----------|----------|--------|---------|------------|----|----|------------|---------|-------|
|Not used | quiet NaN | sign NaN | +infty | +normal | +subnormal | +0 | -0 | -subnormal | -normal | -infty|


Instructions for converting or moving data between integer and floating point registers:
|instr   | algo                                                        |
|--------|-------------------------------------------------------------|
|FCVTWS  | float to int conversion                                     |
|FCVTWUS | float to unsigned int conversion                            |
|FCVTSW  | int to float conversion                                     |
|FCVTSWU | unsigned int to float conversion                            |
|FMVXW   | copy bit pattern from int to float register (no conversion) |
|FMVWX   | copy bit pattern from float to int register (no conversion) |

That's mostly it. There is also a version of load and store that
operate on floating point registers:

|instr   | algo                   |
|--------|------------------------|
|FLW     | rd <- mem[rs1 + Iimm]  |
|FSW     | mem[rs1 + Simm] <- rs2 |

*Side note 1: unlike the other load and store instructions, the address
is not required to be 32-bits aligned. But in practice, it seems that gcc
always generates 32-bit aligned operands for FLW and FSW (I have not
implemented unaligned operands for FLW/FSW in my core).* 

*Side note 2: for a core that implements the compressed instruction
subset (RV32C), there are two compressed variants of FLW and FSW.*

The single-precision IEEE754 representation 
-------------------------------------------

Single-precision floating point numbers use 32 bits as follows:

|sign| exponent |fraction|
|----|----------|--------|
|31  | 30:23    |22:0    |

The represented number is +/- frac * 2^(exp-127-23):

- bit 31 indicates whether the number is positive (0) or negative (1)
- fraction has an additional implicit 24th bit, at the most
  significant position, always set to 1 (except some special cases, 
  including representation of zero). Hence fraction is {1'b1,fraction[22:0]}
- there is a 127 bias applied to the exponent (0 corresponds to 2^(-127)).
  The additional (-23) bias is there between it is bit 23 that is the
  bit set at the most significant position (hence fraction^-23 is always a
  number between 1 and 2).

Internally, in the FPU, we are going to manipulate floating-point numbers with
nearly the same representation, except that bit 23 will be explicit.
For instance, a given number A will be represented by:
- A_sign (1-bit sign)
- A_exp  (biased exponent)
- A_frac (24-bit fraction, with explicit 24th bit)

In this representation, a number is said to be *normalized* if the
leftmost bit set is bit 23. All our RV32F instructions are supposed
to output normalized numbers (except for very small numbers called
*denormals*, but we will not consider them for now). 

Product
-------

The product is the easiest operation to implement, especially if you
have DSP blocks. Let us see how to implement X <= A*B. It is clear that
we are going to have something like:
- `X_sign = A_sign ^ B_sign` 
- `X_exp  = A_exp  + B_exp  (+ adjustment for normalization)`
- `X_frac = A_frac * B_frac (shifted for normalization)`

If A_frac and B_frac use 24 bits, X_frac can take up to 48 bits. We
are going to store X as follows:
- `X_sign` (1-bit sign)
- `X_exp`  (biased exponent, signed, to detect underflows)
- `X_frac` (48-bit fraction, normalized if leading one is bit 47)

The represented number in X is +/- frac * 2^(exp-127-47):

The product to compute is:
```
A*B = (A_sign*B_sign)*(A_frac*B_frac)*2^(A_exp+B_exp-127-127-23-23)
```
Equating with:
```
X = X_sign*A_frac*2^(X_exp-127-47)
```
We obtain, if leading one in (A_frac*B_frac) is bit 47:
```
X_exp  = A_exp + B_exp - 127 + 1
```

It is easy to check that in our case (no denormals), if 
A and B are different from zero, the leading one in (A_frac*B_frac) 
can be either bit 47 or bit 46. If it is bit 46, then `X_frac` needs
to be shifted left by one bit, and `X_exp` needs to be decremented.

Putting everything together, we obtain:
```
   AB_frac = A_frac * B_frac
   X_frac  = AB_frac[47] ? AB_frac : AB_frac << 1
   X_exp   = A_exp + B_exp - 127 + AB_frac[27]
   X_sign  = A_sign ^ B_sign
```

Note that one needs also to detect overflows and underflows (by making
X_exp a signed quantity and using guard bits). 

The truncated 32-bit result can be extracted from X:
```
  product = {X_sign, X_exp[7:0], X_frac[46:24]}
```
This implements the most trivial round-to-zero rounding mode. Other
rouding modes need more work (we just consider round-to-zero for now).

As can be seen, except the special cases (underflow, overflow, zero, 
NaNs, infinities), floating point product is a simple operation, 
especially if you have a DSP that computes `A_frac * B_frac`.

Sum
---

Sum is much mode complicated than product. In our FPU, sum is
implemented with the double-precision register `X`. We will see
later that is it useful to to so, for the FMA operations. We
are going to use a second double-precision register `Y`, to store
the other operand of the addition. 

Basically, we are going to compute `X_frac + Y_frac`, but for this to be 
valid, `X_exp` and `Y_exp` need to match. Once the addition is computed, we need to 
make sure the result is normalized, that is, that the leading one
is bit 47. This requires the following four substeps.

|  step            | algorithm
|------------------|-----------------------------------------------------------------------|
| `ADD_SWAP`       | if abs(X) > abs(Y) swap(X,Y)                                          |
| `ADD_SHIFT`      | shift X to make it match Y exponent                                   |
| `ADD_ADD`        | X_frac <- Y_frac + X_frac (or Y_frac - X_frac if signs differ)        |
| `ADD_NORMALIZE`  | shift X and adjust X_exp in function of leading one position in X_frac|

- for `ADD_SWAP`, comparing the absolute values of the operands means
  first compare the exponents, and if they are the same, compare the
  fractions, that is, lexicographic order with (exponent,fraction);
- for `ADD_SHIFT`, left shift amount to be applied to `X` is `Y_exp` - `X_exp`
- for `ADD_ADD`, if signs differ, `X_frac` is replaced with -`X_frac`.
  Then, `X_frac` is replaced with `X_frac`+`Y_frac`, and `X_exp` is replaced with
 `Y_exp`;
- for `ADD_NORMALIZE`, one first needs to determine the leading one
  position (LOP), then shift `X_frac` (and adjust `X_exp` accordingly)
  in such a way that LOP becomes 47. There are two cases:
  - If LOP=48, then `X_frac` is shifted to the right, and `X_exp` is incremented; 
  - else `X_frac` is shifted to the left LOP times, and `X_exp` is
    decremented by LOP. 

Now we need to determine LOP (leading one position) in `X_frac`. There
is a smart algorithm described 
[here](https://electronics.stackexchange.com/questions/196914/verilog-synthesize-high-speed-leading-zero-count)
that I'm using in "PetitBateau". There is an alternative (Dean
Gaudet's algorithm) described in "Hacker's Delight", Page 110 (I
haven't tested it yet). Here is a short description of the algorithm
in the link above. The algorithm counts the number of leading
zeroes (CLZ). It works recursively, as follows: CLZ can be defined
recursively:
```
   CLZ({a,b}) = (CLZ(a) == n) ? n + CLZ(b) : CLZ(a)
```
where `a` and `b` are both n bits wide. Now if n is a power of two, it
makes things easier, and the addition `n + CLZ(b)` can be directly
computed as a trivial bit operation. I was completely amazed to see in 
the link above (stackoverflow answer) that Verilog accepts recursive
definitions, like modern C++ !  Note that in our case, the input has
48 bits (not a power of two), so we need to pad it to the left with
zeroes to get 64 bits (and Yosys will probably efficiently propagate
the constants, but I did not check). Then, it is clear that LOP 
(Leading One Position) can be deduced, as `LOP = 63 - CLZ`.

*Side note: the `CLZ` trick is super smart, but it introduces some 
combinatorial depth in the adder, especially if one wants to compute it
at the same clock tick as the addition (the input of CLZ is the output
of the addition). However, there exists some "Leading One Prediction" 
algorithms that can be executed in parallel with the addition, and that
give the position of the leading one with at most one bit of error
(then one can check right after the addition and shift the result
accordingly). The benefit is that it makes it possible to merge two
steps of the addition algorithm. I have not tried that yet.*

FMA (Fused Multiply Add)
------------------------

The RV32F subset introduces four FMA instructions. These instructions
compute `A*B+C` (with all possible sign combinations hence four
variants). It is interesting that the norm introduces this instruction 
for two reasons:
- it lets the implementation optimize it, and have higher performance
 than doing `FMUL` then `FADD`;
- the norm specifies that the rounding will be done at the end. The 
 addition is computed with the full precision.
 
With our multiplier and adder defined in the previous two subsections,
we are completely equipped to implement FMA. Supposing that `A`,`B` and
`C` are initialized with `rs1`, `rs2` and `rs3`:
- the first step will load `A*B` in `X` and `C` in `Y` (and changes
  the signs depending on the instruction). This can be done
  in one cycle (remember: computing a product is easy, because it does not
  need shifting the operands, and post-normalization is simple);
- then one only needs to apply `ADD_SWAP`, `ADD_SHIFT`, `ADD_ADD` 
  and `ADD_NORM` as defined in the previous subsection.

FMIN, FMAX, FEQ, FLE, FLT
-------------------------

To implement `ADD_SWAP`, we have created circuitry to compare
exponents and fractions. It is easy to complete this circuitry with signs
comparison to implement these 5 instructions.

FDIV
----

FDIV is more complicated to implement. There are
several options: for FDIV, one can use one of the standard algorithm
(restoring or non-restoring division), as we have done for the RV32M
subset, but it will use a significant quantity of additional resources.
For "PetitBateau", I chose instead to reuse the FMA unit, and compute
`1/rs2` numerically, using Newton-Raphson iterations, then the product
with `rs1` using the multiplier. The algorithm is described 
[here](https://en.wikipedia.org/wiki/Division_algorithm#Newton%E2%80%93Raphson_division).
The algorithm first computes 1/rs2 then multiplies it with rs1. It can be summarized as follows
(please refer to the link above for the full explanation of the algorithm):
```
   D' <- rs2 with exponent scaled (D' in [0.5,1.0])
   X  <- 48/17 - 32/17 D'
   repeat 3 times
      X <- X + X * (1.0 - D' * X)
   end
   X <- rs1 (with exponent scaled) * X 
```

Note that the main loop of the algorithm can be implemented using two
FMAs:
```
   tmp <- FMA(-D',X,1.0)
   X   <- FMA(X,X,tmp)
```

To implement the algorithm, we need to create additional things in the
FPU:
- two new single-precision registers `D` and `E` to store temporary values;
- a micro-coded ROM that will contain the algorithm

The micro-coded ROM is associated with a super simple execution unit,
that uses exactly one cycle per instruction. Instructions are executed
in a sequential flow: except a special flag `FPMI_EXIT_FLAG` that
indicates when the last instruction of a micro-program is reached, there
is no flow control:

```
   wire [6:0] fpmi_PC_next = 
               wr                             ? fpmprog   :
	       fpmi_instr[FPMI_EXIT_FLAG_bit] ? 0         : 
                                                fpmi_PC+1 ;
   always @(posedge clk) begin
      fpmi_PC <= fpmi_PC_next;
      fpmi_instr <= fpmi_ROM[fpmi_PC_next];
   end
```
(where fpmprog selects the micro-program to be executed in function of the
current Risc-V instruction).


The Newton-Raphson algorithm for computing the 
reciprocal `1/rs1` requires three iterations to converge. The three
iterations are explictly encoded in the ROM (remember, we have no
branching instructions). The following micro-instructions are
implemented:

| micro-instruction | algorithm                                 |
|-------------------|-------------------------------------------|
| FPMI_LOAD_XY      | X<-A; Y<-B                                |
| FPMI_LOAD_XY_MUL  | X<-A*B; Y<-C                              |
| FPMI_ADD_SWAP     | if abs(X)>abs(Y) swap(X,Y)                |
| FPMI_ADD_SHIFT    | shift X to match Y exponent               | 
| FPMI_ADD_ADD      | X <- X + Y                                |
| FPMI_ADD_NORM     | X <- normalize(X)                         |
| FPMI_FRCP_PROLOG  | D<-A; E<-B; A<-(-D'); B<-32/17; C<-48/17  |
| FPMI_FRCP_ITER1   | A <- -D'; B <- X; C <- 1.0f               |
| FPMI_FRCP_ITER2   | A <- X; C <- B                            |
| FPMI_FRCP_EPILOG  | A <- (E_sign,frcp_exp,X_frac); B <- D     |

where `D'` = denominator (rs2) normalized between [0.5,1] (set exp to 126).

Using these instructions, `FDIV` is implemented by the following microcode:
```
FPMI_FRCP_PROLOG
FMA
generate three times
   FPMI_FRCP_ITER1
   FMA
   FPMI_FRCP_ITER2
   FMA
FPMI_FRCP_EPILOG
FPMI_LOAD_XY_MUL
```
where `FMA` is expanded into five instructions: `FPMI_LOAD_XY_MUL`, `FPMI_ADD_SWAP`,
`FPMI_ADD_SHIFT`, `FPMI_ADD_ADD`, `FPMI_ADD_NORM`. 

The micro-program ROM is generated in an `initial` block. Here is the extract that
corresponds to `FDIV`:
```
   integer I;    // current ROM location in initialization
   integer iter; // iteration variable for Newton-Raphson (FDIV,FSQRT)
   initial begin
       I = 0;
         .
	 .
	 .
      `FPMPROG_BEGIN(FPMPROG_DIV);      
      // D' = denominator (rs2) normalized between [0.5,1] (set exp to 126)
      fpmi_gen(FPMI_FRCP_PROLOG); // D<-A; E<-B; A<-(-D'); B<-32/17; C<-48/17
      fpmi_gen_fma(0);            // X <- A*B+C (= -D'*32/17 + 48/17)
      for(iter=0; iter<3; iter++) begin
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
      fpmi_gen(FPMI_FRCP_EPILOG); // A <- (E_sign,frcp_exp,X_frac); B <- D
      fpmi_gen(FPMI_LOAD_XY_MUL | FPMI_EXIT_FLAG); // X <- A*B
      `FPMPROG_END(FPMPROG_DIV);
      .
      .
      .
 end     
```

*Side note: there is also a faster but less precise version (set
PRECISE_DIV to 0 to enable it). It uses for the main iteration `X <-
X*(2 - D'X)`, which involves an FMA and a product (instead of two
FMAs, which saves 4 cycles per iteration). However, although the
formula is mathematically equivalent as the version with two FMAs, it
is not computationally equivalent (it is less accurate).  Anyway, none
of the two versions has correct IEEE-754 rounding though (this is
because we compute `round(round(1/y)*x)` instead of `round(x/y)`).*

Under the hood, there is an `fpmi_gen` task, that generates a given
micro-instruction in the ROM and increments the current ROM location `I`:
```
   // Generate a micro-instructions in ROM 
   task fpmi_gen; input [6:0] instr; begin
      fpmi_ROM[I] = instr;
      I = I + 1;
   end endtask   
```

We often need to generate FMAs, so there is also a task for that:
```
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
```

There is also the pair of macros `FPMPROG_BEGIN` and `FPMPROG_END` macros
that store the starting address of each micro-program and 
displays the number of micro-instructions.

FSQRT
-----

Similarly, `FSQRT` is computed by a Newton-Raphson algorithm described
[here](https://en.wikipedia.org/wiki/Fast_inverse_square_root). The
algorithm is well known for its use in the Quake game (successor of Doom).
The algorithm computes an approximation of `1/sqrt(x)` (that one can 
multiply with `x` to get the square root of `x`):

```
   X2 <- 0.5 * rs1
   X <- 0x5f3759df - ( X2 >> 1 )
   X <- X * (3/2 - (X2 * X * X)
   X <- X * (3/2 - (X2 * X * X)
   X <- X * rs1
```

In our case, to gain sufficient precision, we keep two Newton-Raphson
iteration (the second one  is commented-out in Quake sources). The algorithm needs
a couple of additional micro-instructions, for moving data between 
registers and for loading some special constants. The micro-code looks
like:

|Cycle | Micro-instruction  | Algorithm                                       |
|------|--------------------|-------------------------------------------------|
|  1   | FPMI_FRSQRT_PROLOG |  D<-rs1; E,A,B<-(doom_magic - (A >> 1)); C<-3/2 |
|      | *first iteration*  |                                                 |
|  2   | FPMI_LOAD_XY_MUL   | X <- A*B; Y <- C                                |
|  3   | FPMI_MV_A_X        | A <- X                                          |
|  4   | FPMI_MV_B_NH_D     | B <- -0.5*abs(D)                                |
|  5   | FMA	            | X <- A*B+C                                      |
| 10   | FPMI_MV_A_X        | A <- X                                          |
| 11   | FPMI_MV_B_E        | B <- E                                          |
| 12   | FPMI_LOAD_XY_MUL   | X <- A*B; Y <- C                                |
| 13   | FPMI_MV_E_X        | E <- X                                          |
| 14   | FPMI_MV_A_X        | A <- X                                          |
| 15   | FPMI_MV_B_E        | B <- E                                          |
|      | *second iteration* |                                                 |
| 16   | FPMI_LOAD_XY_MUL   | X <- A*B; Y <- C                                |
| 17   | FPMI_MV_A_X        | A <- X                                          |
| 18   | FPMI_MV_B_NH_D     | B <- -0.5*abs(D)                                |
| 19   | FMA	            | X <- A*B+C                                      |
| 24   | FPMI_MV_A_X        | A <- X                                          |
| 25   | FPMI_MV_B_E        | B <- E                                          |
| 26   | FPMI_LOAD_XY_MUL   | X <- A*B; Y <- C                                |
| 27   | FPMI_MV_A_X        | A <- X                                          |
| 28   | FPMI_MV_B_D        | B <- D                                          |
| 29   | FPMI_LOAD_XY_MUL   | X <- A*B; Y <- C                                |

As can be seen, there is a couple of new micro-instructions:
`FPMI_FRSQRT_PROLOG` that computes the initialization (using the
famous `doom_magic=0x5f3759df` constant), and some micro-instructions
to copy data between registers A,B,C,D,E,X,Y (plus a special one,
`MV_B_NH_D` that copies minus half the absolute value of `Ð` into `B`.

Float to int conversion: FCVTWS, FCVTWUS
----------------------------------------

The two float to int conversion instructions take a floating-point
register and convert it to an integer, stored in an integer register
(two versions, one for signed and one for unsigned integers). The
number to be converted is first loaded in the X register. Then,
the fraction is shifted (depending on the exponent). 
The shift is exp - 127 - 23 - 6. The additional bias of -6 comes from
the fact that this is bit 29 of X that corresponds to bit 47 of X_frac
instead of bit 23 (and 23 - 29 = -6). We need to test whether it is a
left shift or a right shift, and test for underflows (we need to test
for overflows as well, not done yet):
```
   wire signed [8:0]  fcvt_ftoi_shift = A_exp - 9'd127 - 9'd23 - 9'd6; 
   wire signed [8:0]  neg_fcvt_ftoi_shift = -fcvt_ftoi_shift;
   wire [31:0] 	X_fcvt_ftoi_shifted =  fcvt_ftoi_shift[8] ? // R or L shift
                        (|neg_fcvt_ftoi_shift[8:5]  ?  0 :  // underflow
                     ({X_frac[49:18]} >> neg_fcvt_ftoi_shift[4:0])) : 
                     ({X_frac[49:18]} << fcvt_ftoi_shift[4:0]);
```

Int to float conversion: FCVTSW, FCVTSWU
----------------------------------------

Converting from int to float requires to determine the leading one
position. To do so, we reuse the CLZ circuit used by the adder. That
is, we load a non-normalized number in Y (with fraction set to the 
integer number, and exponent set to 1), and load 0 in X. Then we just
need to call `FPMI_ADD_ADD` (that adds zero !) and `FPMI_ADD_NORM` 
(to normalize the number). 

Other instructions
------------------

The remaining instructions are very easy to implement:

- data movement without conversion: `FMVXW`, `FMVWX`
- sign injection: `FSGNJ`, `FSGNJN`, `FSGNJX`
- classification: `FCLASS`

Simulation and Testing
----------------------

The FPU is a very complicated piece of hardware, and there was very
little chances for it to work directly (because `I` have implemented
it !!). To ease debugging, it was very important to have a testing framework that lets test the
FPU in realistic cases (for instance, when running `mandel_float` or
`tinyraytracer`), and that lets examine what's going on in the FPU.
Verilator (simulation) helps a lot ! I implemented a simulation of
the small SSD1351 OLED display
[here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/SIM/SSD1351.h),
and a set of functions to test the FPU
[here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/SIM/FPU_funcs.cpp).
The functions that test the FPU can be used in three different ways:
- *replace the FPU*, if the macro `FPU_EMUL` is defined in `petitbateau.v`, then
  the FPU instructions are completely emulated by the host's CPU that
  does the simulation. I used that to test the logic, instruction
  decoder, and datapath;
- *test the algorithm*, in `FPU_funcs.cpp`, if `use_soft_fpu` is set,
  then it will use a C++ implementation of the instructions, that
  operate at a bit level;
- *compare the result of the FPU* it can also be used to compare the
  result computed by the Verilog FPU and the result obtained in the 
  host CPU. It is interesting to see how far away we are from an
  IEEE-754 compliant FPU. As you can see in `PetitBateau.v`, the tests
  for `FDIV` and `FSQRT` are commented-out. If you reactivate them,
  you will see clearly that these two instructions are not IEEE-754 compliant
  yet !
  
Using this framework was *very* comfortable: I started with a fake
FPU, completely implemented in C++. In addition, my simulation code
outputs all the used instructions at the end of the simulation. I 
adopted a *fake it until you make it* approach: I
started with `mandel_float` computed with `-O0`, seeing that I needed
`FLW`,`FSW`,`FADD`,`FSUB`,`FMUL` and `FLE`. So I started implementing
these 5 ones in Verilog. When it worked on the simulator, I tested on
my ARTY. Then I computed with `-O3`, tested again in the simulator:
now uses the `FMADD` functions, so I implemented them, tested in
Verilator, and then on the ARTY once it worked on the Verilator, and
so on and so forth (and `tinyraytracer` compiled in `-O3` nearly uses
the whole instruction set, except `FCLASS`). 

The next steps
--------------
- find a way of having correct rounding for `FDIV and `FSQRT
- implement the other rounding modes
- implement all particular cases (overflow, underflow, NaNs, infinities)
- implement denormals
- make a pipelined version 
- RV32D 'bigmac' version
- Zfinx support (registers shared by integer and fp units)
- optimized version that uses DSP primitives (e.g., on ARTY)
- vector extension, using pipelined version

References 
==========
- [Modern Computer Arithmetics](https://members.loria.fr/PZimmermann/mca/mca-cup-0.5.9.pdf)
- [DSP48E1-FP github](https://github.com/fbrosser/DSP48E1-FP)
- [Iterative FP using DSPs](https://warwick.ac.uk/fac/sci/eng/people/suhaib_fahmy/publications/fpl2013-brosser.pdf)
- [iDEA SDP-based soft proc](https://warwick.ac.uk/fac/sci/eng/people/suhaib_fahmy/publications/trets2014-cheah.pdf)
- [DeCO](https://abhishekkumarjain.github.io/files/FCCM2016.pdf)
- [DeCO slides](https://abhishekkumarjain.github.io/files/FCCM2016-slides.pdf)
- [Reconfigurable Custom FP (1)](https://www.microsoft.com/en-us/research/publication/reconfigurable-custom-floating-point-instructions/)
- [Reconfigurable Custom FP (2)](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/Reconfigurable20Custom20Floating-Point20Instructions_v2.pdf)

- [Newton-Raphson division](https://en.wikipedia.org/wiki/Division_algorithm#Fast_division_methods)
- [Dan Shanley's FPU](https://github.com/danshanley/FPU)
- [A risc-V FPU in verilog](https://github.com/taneroksuz/riscv-fpu)
- [Pulp risc-V FPU](https://github.com/pulp-platform/fpnew)
- [MIT course reports](http://csg.csail.mit.edu/6.375/6_375_2019_www/handouts/finals/Group_2_report.pdf)
- [Proc with FPU](https://github.com/cr88192/bgbtech_btsr1arch)

- [Bogdan Mihai Pasca Ph.D thesis](https://tel.archives-ouvertes.fr/tel-00654121v2/document)

- [A FPU written in system verilog](https://github.com/taneroksuz/riscv-fpu)
- [How to subtract IEEE-754 numbers](see https://stackoverflow.com/questions/8766237/how-to-subtract-ieee-754-numbers)
