.include "femtorv32.inc"

# This version for processors that have a 64-bits ticks counter.

.ifdef CYCLES_64
.global	cycles
.type	cycles, @function

cycles:
	rdcycleh a1
	rdcycle  a0
	rdcycleh t0
	bne t0, a1, cycles
	ret
.endif	


	
