# Simple blinker

.equ IO_BASE, 0x400000  
.equ IO_LEDS, 4

.section .text

.globl main

main:
        li   gp,IO_BASE
	li   sp,0x1800
.L0:
	
	li   t0, 5
	sw   t0, IO_LEDS(gp)
	call wait
	li   t0, 10
	sw   t0, IO_LEDS(gp)
	call wait
	j .L0


