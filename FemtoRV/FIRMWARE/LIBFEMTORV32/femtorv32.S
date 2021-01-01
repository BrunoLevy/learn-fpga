.include "femtorv32.inc"

#################################################################################

# FemtoRV32 support library

# exit function: display exit code
# on LEDS, or spinning wheel if exit
# code is zero.	
.global exit
.type  exit, @function
exit:   
	sw a0, IO_LEDS(gp) # display exit code
exitl1:   	
	bnez a0, exitl1    # if exit code is non-0, loop.
exitl:
	li t0, 1
	sw t0, IO_LEDS(gp)
	li a0, 100
	call milliwait
	li t0, 2
	sw t0, IO_LEDS(gp)
	li a0, 100	
	call milliwait
	li t0, 4
	sw t0, IO_LEDS(gp)
	li a0, 100	
	call milliwait
	li t0, 8
	sw t0, IO_LEDS(gp)
	li a0, 100	
	call milliwait
        j exitl
	
.global abort
.type   abort, @function
abort:	ebreak
	ret
