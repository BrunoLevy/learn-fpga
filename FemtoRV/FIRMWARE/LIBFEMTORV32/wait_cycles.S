.include "femtorv32.inc"

#################################################################################

.global	wait_cycles
.type	wait_cycles, @function

# \brief wait a number of cycles
# \param a0 number of cycles to wait
wait_cycles:
        li   t0, IO_HW_CONFIG_CPUINFO # read CPUINFO HW-config 
        add  t0, t0, gp
	lw   t0, 0(t0)                    
	srli t0, t0, 26               # extract CPL (Cycles per Loop)
.L1:	sub  a0, a0, t0
        bge  a0, zero, .L1
	ret
	
