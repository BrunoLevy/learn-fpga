# Testing the serial interface. Echoes typed characters,
# and displays 4 LSBs using the LEDs.

# Needs both NRV_IO_UART_RX and NRV_IO_UART_TX to be
# enabled. 
#
# To access it, use:
#   miniterm.py --dtr=0 /dev/ttyUSB1 115200
#   or screen /dev/ttyUSB1 115200 (<ctrl> a \ to exit)

.include "LIB/femtorv32.inc"

.globl main
.type  main, @function

main:   add sp,sp,-4
        sw ra, 0(sp)	
loop:   call get_char
	sw a0,IO_LEDS(gp)	
        call put_char
	j loop
	lw ra, 0(sp)
	add sp,sp,4
	ret

