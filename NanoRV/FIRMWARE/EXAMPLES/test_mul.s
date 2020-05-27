.section .text
.globl _start
.include "nanorv.s"
	
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
	
