# Testing the serial interface. Echoes typed characters,
# and displays 4 LSBs using the LEDs.

.section .text
.globl _start
.include "nanorv.s"

# Needs both NRV_IO_UART_RX and NRV_IO_UART_TX to be
# enabled. 
#
# To access it, use:
#   miniterm.py --dtr=0 /dev/ttyUSB1 115200
#   or screen /dev/ttyUSB1 115200 (<ctrl> a \ to exit)


_start: 
        call get_char
	sw a0,IO_LEDS(gp)	
        call put_char
	j _start

