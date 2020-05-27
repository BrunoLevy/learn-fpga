.section .text
.globl _start
.include "nanorv.s"

.equ mandel_shift, 10
.equ mandel_mul,(1 << mandel_shift)	
.equ xmin, -2*mandel_mul
.equ xmax,  2*mandel_mul
.equ ymin, -2*mandel_mul
.equ ymax,  2*mandel_mul	
.equ dx, (xmax-xmin)/128
.equ dy, (ymax-ymin)/128
.equ norm_max,(4 << mandel_shift)

# X,Y  : s0,s1
# Cr,Ci: s2,s3
# 128: s11

clear:  mv s2,ra
        OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED0 0x5c                   # write RAM
	li t0,0
	li s11,128
	li s1,0
cloop_y:li s0,0
cloop_x:sw t0,IO_OLED_DATA(gp)
	call oled_wait 
	sw t0,IO_OLED_DATA(gp)
	call oled_wait 
	add s0,s0,1
	bne s0,s11,cloop_x
	add s1,s1,1
	bne s1,s11,cloop_y
	mv ra,s2
	ret

_start:
	call oled_init

	li t0, 15
	sw t0, IO_LEDS(gp)

        call clear

	li s11,128	
	li s9,0

anim:	OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED0 0x5c                   # write RAM
	li s1,0
	li s3,xmin
	
loop_y:	li s0,0
        li s2,ymin
loop_x:	

        mv a0,s2
	mv a1,s2
	call __muldi3
	mv s10,a0

        mv a0,s3
	mv a1,s3
	call __muldi3
	add s10,s10,a0

        srli s10,s10,10
	slli t0,s9,7
	sub s10,s10,t0

        srli t1,s10,5
	mv   t0,t1
	sll  t0,t0,3
	sw   t0,IO_OLED_DATA(gp)
#	call oled_wait 

        srli t1,s10,5
	mv   t0,t1
	andi t0,t0,31
	sw   t0, IO_OLED_DATA(gp)
#	call oled_wait 
	
	add s0,s0,1
	add s2,s2,dx
	bne s0,s11,loop_x
	
	add s1,s1,1
	add s3,s3,dy
	bne s1,s11,loop_y
	
	sw s9, IO_LEDS(gp)
	
	add s9,s9,1
	j anim


