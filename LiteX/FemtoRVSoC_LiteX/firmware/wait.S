.section .text
.globl wait

wait:
        li t0,1
	slli t0, t0,17
.L0:       
        addi t0,t0,-1
	bnez t0, .L0
	ret

