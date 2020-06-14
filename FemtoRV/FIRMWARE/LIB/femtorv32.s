.include "femtorv32.inc"

#################################################################################

# NanoRv support library

# exit function: display exit code
# on LEDS, or spinning wheel if exit
# code is zero.	
.global exit
.type  exit, @function
exit:   mv t0, a0
	li a0, 100
	sw t0, IO_LEDS(gp)
	bnez t0, exit
exitl:	li t0, 1
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
	
# Wait for a while	
.global	wait
.type	wait, @function
wait:	li t0,0x100000
waitl:	add t0,t0,-1
	bnez t0,waitl
	ret


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
	bnez t0,waitl
	ret

	
.global abort
.type   abort, @function
abort:	ebreak
	ret
