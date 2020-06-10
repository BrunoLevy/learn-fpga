.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
   li gp,IO_BASE # base address of memory-mapped IO
   li sp,0x1000  # initial stack pointer, stack goes downwards
   call main
   tail exit
   
