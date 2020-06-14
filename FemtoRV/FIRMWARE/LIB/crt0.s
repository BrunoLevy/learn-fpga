.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
     li gp,IO_BASE # base address of memory-mapped IO
     
     # test memory sizes by storing and reading 
     # 'magic' 0xfeedbeef value.
     
     li t0,0xfeedbeef
     
     # Do we use 6K configuration ?
     li sp,0x17FF
     sw  t0,0(sp)
     lw  t1,0(sp)
     beq t0,t1,.L1
     
     # Do we use 5K configuration ?
     li sp,0x13FF
     sw  t0,0(sp)
     lw  t1,0(sp)
     beq t0,t1,.L1

     # Do we use 4K configuration ?
     li sp,0x0FFF
     sw  t0,0(sp)
     lw  t1,0(sp)
     beq t0,t1,.L1
     
     # If we are here, we are in big trouble !
     tail abort

.L1: add sp,sp,1
     call main
     tail exit
   
