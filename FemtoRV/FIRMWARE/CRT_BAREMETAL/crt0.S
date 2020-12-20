.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li gp,IO_BASE       #   Base address of memory-mapped IO
.option pop
	
     lw sp,IO_RAM(gp)      # Read RAM size in hw config register and
        	           #   initialize SP one position past end of RAM
     call main
     tail exit


