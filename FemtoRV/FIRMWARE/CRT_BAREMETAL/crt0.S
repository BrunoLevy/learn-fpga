.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li gp,IO_BASE       #   Base address of memory-mapped IO
.option pop

     li   t0,IO_HW_CONFIG_RAM  # Can't use IO_HW_CONFIG_RAM(gp) (too far away !)
     add  t0,t0,gp             # Read RAM size in hw config register and
     lw   sp,0(t0)             # initialize SP at end of RAM
     li   t0,0                 # reset t0 to 0

# TODO: clear BSS (for this we need a linker script that declares _edata)
#     la t1,_edata
#.L1: sw zero,0(t1)
#     addi t1,t1,4
#     bne t1,sp,.L1	
	
     call main
     tail exit


