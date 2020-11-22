/* Taken from:
 * https://gitlab.cs.fau.de/osek-v/riscv-gnu-toolchain/commit/  445854900f679290ecca96390435c85d812fdec0
 * (and removed RV64 stuff)
 */

  .globl __divsi3
__divsi3:
  bltz  a0, .L10
  bltz  a1, .L11
  /* Since the quotient is positive, fall into __udivdi3.  */

  .globl __udivsi3
__udivsi3:
  mv    a2, a1
  mv    a1, a0
  li    a0, -1
  beqz  a2, .L5
  li    a3, 1
  bgeu  a2, a1, .L2
.L1:
  blez  a2, .L2
  slli  a2, a2, 1
  slli  a3, a3, 1
  bgtu  a1, a2, .L1
.L2:
  li    a0, 0
.L3:
  bltu  a1, a2, .L4
  sub   a1, a1, a2
  or    a0, a0, a3
.L4:
  srli  a3, a3, 1
  srli  a2, a2, 1
  bnez  a3, .L3
.L5:
  ret

  .globl __umodsi3
__umodsi3:
  /* Call __udivsi3(a0, a1), then return the remainder, which is in a1.  */
  move  t0, ra
  jal   __udivsi3
  move  a0, a1
  jr    t0

  /* Handle negative arguments to __divsi3.  */
.L10:
  neg   a0, a0 
  bgez  a1, .L12      /* Compute __udivsi3(-a0, a1), then negate the result.  */
  neg   a1, a1
  j     __divsi3      /* Compute __udivsi3(-a0, -a1).  */
.L11:                 /* Compute __udivsi3(a0, -a1), then negate the result.  */
  neg   a1, a1
.L12:
  move  t0, ra
  jal   __divsi3
  neg   a0, a0
  jr    t0

  .globl __modsi3
__modsi3:
  move   t0, ra
  bltz   a1, .L31
  bltz   a0, .L32
.L30:
  jal    __udivsi3    /* The dividend is not negative.  */
  move   a0, a1
  jr     t0
.L31:
  neg    a1, a1
  bgez   a0, .L30
.L32:
  neg    a0, a0
  jal    __udivsi3    /* The dividend is hella negative.  */
  neg    a0, a1
  jr     t0

