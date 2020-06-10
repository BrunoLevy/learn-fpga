# Testing the OLED screen, displaying an animated pattern with
# all the 65K colors.

.section .text
.globl _start
.include "LIB/femtorv32.inc"
	
_start:
	call oled_init
	
	# anim
	# s0 = X, s1 = Y, s2 = bound, s3 = frame
	li s2,128	
	li s3,0
anim:	OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED0 0x5c                   # write RAM
	li s1,0
loop_y:	li s0,0
loop_x:	add s0,s0,1

	# compute pixel color: RRRRR GGGGG 0 BBBBB
	# (or an additional G LSB instead of 0)
	#  RRRRR = X+frame
	#  GGGGG = X >> 3
	#  BBBBB = Y+frame

	add t0,s0,s3
	sll t0,t0,3
	
	srl t1,s0,5
	and t1,t1,7
	or  t0,t0,t1
	sw t0, IO_OLED_DATA(gp)
#	call oled_wait  
#         oled_wait not needed here:
#         we just need 8 cycles (or 16 if overclocked at 60 MHz) 
#         before next st xx, IO_OLED_DATA(gp)	
	add t0,s1,s3
	andi t0,t0,31
	sll t1,s0,3
	and t1,t1,192
	or  t0,t0,t1
	sw t0, IO_OLED_DATA(gp)
#	call oled_wait  # not needed here.
	
	bne s0,s2,loop_x
	add s1,s1,1
	bne s1,s0,loop_y
	add s3,s3,1

	sw s3, 0(gp)
	j anim

