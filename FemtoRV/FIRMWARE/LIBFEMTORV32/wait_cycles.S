.include "femtorv32.inc"

#################################################################################

.global	wait_cycles
.type	wait_cycles, @function

# \brief wait a number of cycles
# \param a0 number of cycles to wait
wait_cycles:
	lw   t0, IO_HW_CONFIG_DEVICES_FREQ(gp) # read DEVICES_FREQ HW condig word 
	srli t0, t0, 26              # extract CPL (Cycles per Loop)
.L1:	sub  a0, a0, t0
        bge  a0, zero, .L1
	ret
	
