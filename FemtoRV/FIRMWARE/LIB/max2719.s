.include "femtorv32.inc"


#################################################################################	
# NanoRv led matrix support
#################################################################################

.global	MAX2719
.type	MAX2719, @function
MAX2719: # a0: register  a1: value
         slli t0, a0, 8
	 or  t0, t0, a1
         sw t0, IO_LEDMTX_DATA(gp)  
MAXwait: lw t0, IO_LEDMTX_CNTL(gp)
         bnez t0, MAXwait
	 ret

.global	MAX2719_init
.type	MAX2719_init, @function
MAX2719_init:
	 add sp,sp,-4
         sw ra, 0(sp)	
         li a0, 0x09 # decode mode
	 li a1, 0x00 
	 call MAX2719
	 li a0, 0x0a # intensity
	 li a1, 0x0f
	 call MAX2719
	 li a0, 0x0b # scan limit
	 li a1, 0x07
	 call MAX2719
	 li a0, 0x0c # shutdown
	 li a1, 0x01
	 call MAX2719
	 li a0, 0x0f # display test
	 li a1, 0x00
	 call MAX2719
 	 lw ra, 0(sp)
	 add sp,sp,4
	 ret

        
