.section .text
.globl _start
.include "LIB/femtorv32.inc"

_start:
        call MAX2719_init

anim:   la a0,face1data
	call MAX2719_image
        call wait
        call wait	
	la a0,face2data
	call MAX2719_image
	call wait
        call wait	
	j anim
	

MAX2719_image:
        add sp,sp,-4
        sw ra, 0(sp)
        li s0,1
        mv s1,a0
        li s2,9
MAXil:  mv a0,s0
        lbu a1,0(s1)
	call MAX2719
	add s0,s0,1
	add s1,s1,1
	bne s0,s2,MAXil
	lw ra, 0(sp)
        add sp,sp,4
	ret

	
face1data:
.byte 0b00111100, 0b01000010, 0b10001001, 0b10100001
.byte 0b10100001, 0b10001001, 0b01000010, 0b00111100

face2data:
.byte 0b00000000, 0b00001000, 0b00010100, 0b00101000
.byte 0b00101000, 0b00010100, 0b00001000, 0b00000000


