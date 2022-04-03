# Simple blinker

.equ IO_BASE, 0x400000  
.equ IO_LEDS, 4

.section .text

.globl start

start:
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


wait:
        li t0,1
	slli t0, t0,17
.L1:       
        addi t0,t0,-1
	bnez t0, .L1
	ret

