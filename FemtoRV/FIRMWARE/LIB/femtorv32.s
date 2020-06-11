.include "femtorv32.inc"

#################################################################################

# NanoRv support library

.global exit
.type  exit, @function
exit:
   .word 0  # make it crash...
   ret

# Wait for a while	
.global	wait
.type	wait, @function
wait:	li t0,0x100000
waitl:	add t0,t0,-1
	bnez t0,waitl
	ret

