# Blinker example, using the shift instruction
# Fast version, to be run from the SPI flash (that slows down everything)
.include "femtorv32.inc"

.globl main
.type  main, @function

main:	li   t1,0
	li   t2,15       
loop:	addi t1,t1,1
	call show
	bne  t0,t2,loop
	j    end
end:	j    main
	
show:   srli t0,t1,14
	sw t0,IO_LEDS(gp)
	ret


