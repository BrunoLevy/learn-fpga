.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li gp,IO_BASE       #   Base address of memory-mapped IO
.option pop

     lw sp,IO_HW_CONFIG_RAM(gp) # Read RAM size in hw config register and
                                # initialize SP one position past end of RAM
#     la t1,edata
#.L1: sw zero,0(t1)
#     addi t1,t1,4
#     bne t1,sp,.L1	
	
     call main
     tail exit


