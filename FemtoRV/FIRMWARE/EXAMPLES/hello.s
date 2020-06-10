# Testing the serial interface. Echoes typed characters,
# and displays 4 LSBs using the LEDs.
.include "LIB/femtorv32.inc"

# Needs both NRV_IO_UART_RX and NRV_IO_UART_TX to be
# enabled. 
#
# To access it, use:
#   miniterm.py --dtr=0 /dev/ttyUSB1 115200
#   or screen /dev/ttyUSB1 115200 (<ctrl> a \ to exit)

.globl main
.type  main, @function

main:   add sp,sp,-4
        sw ra, 0(sp)	
loop:   li t0, 15
	sw t0, IO_LEDS(gp)
        call get_char
	la a0, hello
	call print_string
	j loop
	lw ra, 0(sp)
	add sp,sp,4
	ret

hello:
.asciz "Hello, world !!\n"
