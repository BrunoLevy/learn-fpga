# Test for the software multiplication function __muldi3 in nanorv.s
# (to be used with icarus, see TEST/)
# LEDs display 4 LSBs of the result
# Icarus displays value (all 32 bits) sent to mapped LEDs IO.

.section .text
.globl _start
.include "LIB/femtorv32.inc"
	
_start:
	li a0, 6
	li a1, 7
	call __muldi3
	sw a0, IO_LEDS(gp)

	li a0, 6
	li a1, -7
	call __muldi3
	sw a0, IO_LEDS(gp)

	li a0, -6
	li a1, 7
	call __muldi3
	sw a0, IO_LEDS(gp)
	
	li a0, -6
	li a1, -7
	call __muldi3
	sw a0, IO_LEDS(gp)
	
