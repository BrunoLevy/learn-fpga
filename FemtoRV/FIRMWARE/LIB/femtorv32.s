.include "femtorv32.inc"

#################################################################################

# NanoRv support library

# exit function: display exit code
# on LEDS, or spinning wheel if exit
# code is zero.	
.global exit
.type  exit, @function
exit:
	sw a0, IO_LEDS(gp)
	bnez a0, exit
exitl:	li a0, 1
	sw a0, IO_LEDS(gp)
	call wait
	li a0, 2
	sw a0, IO_LEDS(gp)
	call wait
	li a0, 4
	sw a0, IO_LEDS(gp)
	call wait
	li a0, 8
	sw a0, IO_LEDS(gp)
	call wait
        j exitl
	
# Wait for a while	
.global	wait
.type	wait, @function
wait:	li t0,0x100000
waitl:	add t0,t0,-1
	bnez t0,waitl
	ret

.global abort
.type   abort, @function
abort:	ebreak
	ret
