# Jump to program stored in memory-mapped SPI flash
# Mapped SPI address is (1 << 23).
	
.include "femtorv32.inc"

.globl main
.type  main, @function

main: 
   li   t0,1
   slli t0,t0,23
   jr   t0

