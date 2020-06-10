# Blinker example, using the shift instruction
.include "LIB/femtorv32.inc"

.globl main
.type  main, @function

main:   add sp,sp,-4
        sw ra, 0(sp)	
	li   t1,0
	li   t2,15       
loop:	addi t1,t1,1
	call show
	bne  t0,t2,loop
	j    end
end:	lw ra, 0(sp)
	add sp,sp,4
	ret
	
show:   srli t0,t1,18
	sw t0,IO_LEDS(gp)
	ret
	


