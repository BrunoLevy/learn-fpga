.section .text
.globl rdcycle
.globl rdinstret

rdcycle:
.L0:  
   rdcycleh a1
   rdcycle a0
   rdcycleh t0
   bne a1,t0,.L0
   ret

rdinstret:
.L1:  
   rdinstreth a1
   rdinstret a0
   rdinstreth t0
   bne a1,t0,.L1
   ret
