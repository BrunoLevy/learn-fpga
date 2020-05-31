# Testing the serial interface. Echoes typed characters,
# and displays 4 LSBs using the LEDs.

.section .text
.globl _start
.include "nanorv.s"

MAX2719:sw a0,IO_LEDMTX_DATA(gp)
waitMAX:lw t0,IO_LEDMTX_CNTL(gp)
	bnez t0,waitMAX
	ret
	
_start:
        li a0,0x0900  # decode mode
	call MAX2719
	li a0,0x0a0f  # intensity
	call MAX2719
	li a0,0x0b07  # scan limit
	call MAX2719
	li a0,0x0c01  # shutdown
	call MAX2719
	li a0,0x0f00  # display test
	call MAX2719

animate:

	li a0,0x0100  
	call MAX2719	
	li a0,0x02ff  
	call MAX2719	
	li a0,0x0300  
	call MAX2719	
	li a0,0x04ff  
	call MAX2719	
	li a0,0x0500  
	call MAX2719	
	li a0,0x06ff  
	call MAX2719	
	li a0,0x0700  
	call MAX2719
	li a0,0x08ff
	call MAX2719	
	
	call wait
	call wait

	li a0,0x01ff  
	call MAX2719	
	li a0,0x0200  
	call MAX2719	
	li a0,0x03ff  
	call MAX2719	
	li a0,0x0400  
	call MAX2719	
	li a0,0x05ff  
	call MAX2719	
	li a0,0x0600  
	call MAX2719	
	li a0,0x07ff  
	call MAX2719
	li a0,0x0800
	call MAX2719	

	call wait
	call wait

j animate


