# Blinker example, using a delay loop.

.include "femtorv32.inc"

.globl main
.type  main, @function

main:   add sp,sp,-4
        sw ra, 0(sp)
	li   t1,0
	li   t2,15       
loop:	addi t1,t1,1
	call mywait
	call show
	bne  t1,t2,loop
	j    end	
end:    li a0,15     # main() return value, let all leds lit
        lw ra,0(sp)
	add sp,sp,4
	ret

mywait:	li t3,0
	li t4,0x100000
mwaitl:	addi t3,t3,1
	bne t3,t4,mwaitl
	ret
	
show:   addi t0,t1,0
	sw t0,IO_LEDS(gp)
	ret
	


