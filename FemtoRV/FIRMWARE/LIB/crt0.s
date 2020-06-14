.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
     li gp,IO_BASE # base address of memory-mapped IO
     # li sp,0x1800 # 6K
     # li sp,0x1400 # 5K
     li sp,0x1000 # 4K
     call main
     tail exit
   
