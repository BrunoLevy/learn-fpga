.include "femtorv32.inc"


#################################################################################	
# femtorv led matrix support
#################################################################################

.global	MAX7219
.type	MAX7219, @function
MAX7219: # a0: register  a1: value
         slli t0, a0, 8
	 or  t0, t0, a1
         sw t0, IO_MAX7219_DAT(gp)  
	 ret

.global	MAX7219_init
.type	MAX7219_init, @function
MAX7219_init:
	 add sp,sp,-4
         sw ra, 0(sp)	
         li a0, 0x09 # decode mode
	 li a1, 0x00 
	 call MAX7219
	 li a0, 0x0a # intensity
	 li a1, 0x0f
	 call MAX7219
	 li a0, 0x0b # scan limit
	 li a1, 0x07
	 call MAX7219
	 li a0, 0x0c # shutdown
	 li a1, 0x01
	 call MAX7219
	 li a0, 0x0f # display test
	 li a1, 0x00
	 call MAX7219
 	 lw ra, 0(sp)
	 add sp,sp,4
	 ret

        
