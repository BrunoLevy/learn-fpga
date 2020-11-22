.include "femtorv32.inc"

#################################################################################
	
# Wait for an approximate number of milliseconds
.global	microwait
.type	microwait, @function
microwait: sll t0,a0,3
mdelayl: add t0,t0,-1
	 bnez t0,mdelayl
	 ret
	
