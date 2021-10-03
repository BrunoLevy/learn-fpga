Notes on Implementing RV32F
===========================

Let us see if we can make tinyraytracer (and other programs) faster on
FemtoRV, by implementing single-precision floating point instructions.

TL;DR: the FPU is [here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/petitbateau.v).

The RV32F instruction subset
----------------------------

The RV32F instruction subset has 26 (!) instructions. We know that 
implementing them will require some work (to have something that works
almost took me the same amount of work as creating my first RV32IM core,
and it is still not fully compliant with the norm !). 

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
Side note: There exists a different version of the instruction 
subset (Zfinx) that uses a unique register bank for integer and
floating-point registers. Can be interesting for instance to design
a minimalistic floating-point able core, used to design for instance
a GPU-like device with multiple cores.

Then there are the FMA instructions (fused-multiply-add) that computes
rs1*rs2+rs3 in a single instruction (with different sign
combinations):

|instr  | algo                     |
|-------|--------------------------|
|FMADD  | rd <-   rs1 * rs2 + rs3  |
|FMSUB  | rd <-   rs1 * rs2 + rs3  |
|FNMADD | rd <- -(rs1 * rs2 + rs3) |
|FNMSUB | rd <- -(rs1 * rs2 + rs3) |

Side note: there is a *big catch* in the official documentation: they
say FNMADD computes -rs1*rs2-rs3 (which is true, it is an equivalent
formula as what's written in the table above, but it is misleading:
with this formula, FNMADD computes a subtraction). I spent a couple of
hours on this ! (thank you @rob-ng15 for pointing this to me, saved
the day). I think the reason it is written like that in the
documentation is that from an implementation point of view, it is
easier to change the sign of the operands when they are loaded than
the sign of the result in the end.

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

Side note 1: unlike the other load and store instructions, the address
is not required to be 32-bits aligned. But in practice, it seems that gcc
always generates 32-bit aligned operands for FLW and FSW (I have not
implemented unaligned operands for FLW/FSW in my core). 

Side note 2: for a core that implements the compressed instruction
subset (RV32C), there are two compressed variants of FLW and FSW.

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
