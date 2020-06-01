.section .text
.globl _start
.include "nanorv.s"

MAX2719: # a0: register  a1: value
         slli t0, a0, 8
	 or  t0, t0, a1
         sw t0, IO_LEDMTX_DATA(gp)
MAXwait: lw t0, IO_LEDMTX_CNTL(gp)
         bnez t0, MAXwait
	 ret

MAX2719_init:
	 add sp,sp,-4
         sw ra, 0(sp)	
         li a0, 0x09 # decode mode
	 li a1, 0x00 
	 call MAX2719
	 li a0, 0x0a # intensity
	 li a1, 0x0f
	 call MAX2719
	 li a0, 0x0b # scan limit
	 li a1, 0x07
	 call MAX2719
	 li a0, 0x0c # shutdown
	 li a1, 0x01
	 call MAX2719
	 li a0, 0x0f # display test
	 li a1, 0x00
	 call MAX2719
 	 lw ra, 0(sp)
	 add sp,sp,4
	 ret

face1:
        add sp,sp,-4
        sw ra, 0(sp)	
        li a0, 1
	li a1, 0b00111100
        call MAX2719
	li a0, 2
	li a1, 0b01000010
	call MAX2719
	li a0, 3
	li a1, 0b10001001
	call MAX2719
	li a0, 4
	li a1, 0b10100001
	call MAX2719
	li a0, 5
	li a1, 0b10100001
	call MAX2719
	li a0, 6
	li a1, 0b10001001
	call MAX2719
	li a0, 7
	li a1, 0b01000010
	call MAX2719
        li a0, 8
	li a1, 0b00111100
        call MAX2719
	lw ra, 0(sp)
	add sp,sp,4
	ret

face2:
        add sp,sp,-4
        sw ra, 0(sp)	
        li a0, 1
	li a1, 0b00111100
        call MAX2719
	li a0, 2
	li a1, 0b01001010
	call MAX2719
	li a0, 3
	li a1, 0b10011101
	call MAX2719
	li a0, 4
	li a1, 0b10101001
	call MAX2719
	li a0, 5
	li a1, 0b10101001
	call MAX2719
	li a0, 6
	li a1, 0b10011101
	call MAX2719
	li a0, 7
	li a1, 0b01001010
	call MAX2719
        li a0, 8
	li a1, 0b00111100
        call MAX2719
	lw ra, 0(sp)
	add sp,sp,4
	ret


_start:
        call MAX2719_init

anim:   call face1
        call wait
        call wait	
	call face2
	call wait
        call wait	
	j anim
	



