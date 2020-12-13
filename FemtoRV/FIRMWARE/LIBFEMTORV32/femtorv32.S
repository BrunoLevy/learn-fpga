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
	li a0, 100         # for delay if spinning leds
	li t0, 1
	sw t0, IO_LEDS(gp)
	call delay
	li t0, 2
	sw t0, IO_LEDS(gp)
	call delay
	li t0, 4
	sw t0, IO_LEDS(gp)
	call delay
	li t0, 8
	sw t0, IO_LEDS(gp)
	call delay
        j exitl
	
# Wait for an approximate number of milliseconds
#  The femtorv32 core operates at 60 MHz
#  The delay loop uses 7 microcycles
#  One second = 8 571 429 cycles
#   8M cycles = 8 388 608 cycles (not too far)
#  Well, a real-time clock would be better, but
#  I do not have more LUTs available for that...	
.global	delay
.type	delay, @function
delay:	sll t0,a0,13
delayl:	add t0,t0,-1
	bnez t0,delayl
	ret

.global	nanowait
.type	nanowait, @function
nanowait: sll t0,a0,3
ndelayl: add t0,t0,-1
	 bnez t0,delayl
	 ret
	
	
.global abort
.type   abort, @function
abort:	ebreak
	ret
