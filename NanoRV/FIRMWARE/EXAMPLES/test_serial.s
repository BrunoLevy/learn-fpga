.section .text
.globl _start
.include "nanorv.s"

# Needs both NRV_IO_UART_RX and NRV_IO_UART_TX to be
# enabled. Requires NRV_TWOSTAGE_SHIFTER to be deactivated
# (else it will not fit on the Ice40).
#
# To access it, use:
#   miniterm.py --dtr=0 /dev/ttyUSB1 115200
#   or screen /dev/ttyUSB1 115200 (<ctrl> a \ to exit)


_start: 
        # wait for available data and
	# load data in t0
        lw t0,IO_UART_RX_CNTL(gp)
        beqz t0,_start
        lw t0,IO_UART_RX_DATA(gp)
	
	# display data
	sw t0,IO_LEDS(gp)
	
	# send data back and wait for
	# it to be sent
	sw t0,IO_UART_TX_DATA(gp)
rx:	lw t0,IO_UART_TX_CNTL(gp)
	bnez t0,rx
	j _start

