# Computes and displays the Mandelbrot set on the OLED display.
# (needs an SSD1351 128x128 OLED display plugged on the IceStick)
# If you do not have the OLED display, use mandelbrot_terminal.s 
# instead.

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

# X,Y         : s0,s1
# Cr,Ci       : s2,s3
# Zr,Zi       : s4,s5
# Zrr,2Zri,Zii: s6,s7,s8
# cnt: s10
# 128: s11

_start:
	call oled_init
        call oled_clear


        OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED0 0x5c                   # write RAM

	call wait
	li   t0, 0
	sw   t0, IO_LEDS(gp)

	li s1,0
	li s3,xmin
	li s11,128	

loop_y:	li s0,0
        li s2,ymin
	
loop_x: mv s4,s2    # Z <- C
        mv s5,s3
	
	li s10,15   # iter <- 15
	
loop_Z: mv a0,s4    # Zrr  <- (Zr*Zr) >> mandel_shift
        mv a1,s4
	call __muldi3
	srli s6,a0,mandel_shift
	mv a0,s4    # Zri <- (Zr*Zi) >> (mandel_shift-1)
	mv a1,s5
	call __muldi3
	srai s7,a0,mandel_shift-1
	mv a0,s5    # Zii <- (Zi*Zi) >> (mandel_shift)
	mv a1,s5
	call __muldi3
	srli s8,a0,mandel_shift
	sub s4,s6,s8 # Zr <- Zrr - Zii + Cr  
	add s4,s4,s2
        add s5,s7,s3 # Zi <- 2Zri + Cr

        add s6,s6,s8     # if norm > norm max, exit loop
        li  s7,norm_max
	bgt s6,s7,exit_Z

        add s10,s10,-1   # iter--, loop if non-zero
	bnez s10, loop_Z
exit_Z:

	sll  t0,s10,3
	sw   t0,IO_OLED_DATA(gp)
	call oled_wait 	

        sll  t0,s10,2
	sw   t0, IO_OLED_DATA(gp)
	call oled_wait 	
	
	add s0,s0,1
	add s2,s2,dx
	bne s0,s11,loop_x
	
	add s1,s1,1
	add s3,s3,dy
	bne s1,s11,loop_y
	
	li   t0, 15
	sw   t0, IO_LEDS(gp)
	


