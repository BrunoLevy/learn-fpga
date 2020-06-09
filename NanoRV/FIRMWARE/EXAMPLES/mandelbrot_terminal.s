# Computes and displays the Mandelbrot set on the terminal.
# Needs both NRV_IO_UART_RX and NRV_IO_UART_TX to be
# enabled. 
#
# To access it, use:
#   miniterm.py --dtr=0 /dev/ttyUSB1 115200
#   or screen /dev/ttyUSB1 115200 (<ctrl> a \ to exit)

.section .text
.globl _start
.include "nanorv.s"

.equ mandel_shift, 10
.equ mandel_mul,(1 << mandel_shift)	
.equ xmin, -2*mandel_mul
.equ xmax,  2*mandel_mul
.equ ymin, -2*mandel_mul
.equ ymax,  2*mandel_mul	
.equ dx, (xmax-xmin)/80
.equ dy, (ymax-ymin)/80
.equ norm_max,(4 << mandel_shift)

# X,Y         : s0,s1
# Cr,Ci       : s2,s3
# Zr,Zi       : s4,s5
# Zrr,2Zri,Zii: s6,s7,s8
# cnt: s10
# 128: s11


_start:
        la   a0,hello
	call print_string
	
	call wait
	li   t0, 0
	sw   t0, IO_LEDS(gp)

	li s1,0
	li s3,xmin
	li s11,80

loop_y:	li s0,0
        li s2,ymin
	
loop_x: mv s4,s2    # Z <- C
        mv s5,s3
	
	li s10,9   # iter <- 9
	
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
        la  a0,colormap
	add a0,a0,s10
	lbu a0,0(a0)
	call put_char
	
	add s0,s0,1
	add s2,s2,dx
	bne s0,s11,loop_x

        li a0,13
	call put_char
        li a0,10
	call put_char

	add s1,s1,1
	add s3,s3,dy
	bne s1,s11,loop_y
	
	li   t0, 15
	sw   t0, IO_LEDS(gp)

        la   a0, string1
	call print_string
        call get_char
	call put_char
        li a0,13
	call put_char
        li a0,10
	call put_char
	
        j _start


hello:
  .asciz "NanoRV RISC-V processor, Mandelbrot demo\n"

string1:
  .asciz "Press any key to restart:"


colormap:
.ascii " .,:;ox%#@"

