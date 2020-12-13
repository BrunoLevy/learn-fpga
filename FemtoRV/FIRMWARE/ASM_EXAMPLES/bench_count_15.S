# A simple program to be displayed on the test bench
# Counts from 0 to 15, outputs each number to the LEDs, 
# outputs return value 5 at the end.
# (you won't see anything if you run it on the device,
#  it is meant to be used with the iverilog testbench)

.include "femtorv32.inc"

.globl main
.type  main, @function

main:   add sp,sp,-4
        sw  ra, 0(sp)	
	li  t1,0
	li  t2,16
	
loop:   sw  t1,IO_LEDS(gp)
        addi t1,t1,1
	bne  t1,t2,loop
	
	li a0, 5    # main() return value
        lw ra, 0(sp)
	add sp,sp,4
	ret


