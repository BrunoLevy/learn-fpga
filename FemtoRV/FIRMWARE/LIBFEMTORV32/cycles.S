.include "femtorv32.inc"

.ifndef ICE_STICK
.ifndef ICE_BREAKER
.global	cycles
.type	cycles, @function

cycles:
	rdcycleh a1
	rdcycle  a0
	rdcycleh t0
	bne t0, a1, cycles
	ret
.endif	
.endif

	
