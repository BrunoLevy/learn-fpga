# Blinker example, using a delay loop.

.section .text
.globl _start
.equ IO_BASE,      0x1000   # Base address of memory-mapped IO
.equ IO_LEDS,      0        # 4 LSBs mapped to D1,D2,D3,D4

_start:
        li   gp,0x1000
	li   t1,0
	li   t2,15       
loop:	addi t1,t1,1
	call wait
	call show
	bne  t1,t2,loop
	j    end	

wait:	li t3,0
	li t4,0x100000
waitl:	addi t3,t3,1
	bne t3,t4,waitl
	ret
	
show:   addi t0,t1,0
	sw t0,IO_LEDS(gp)
	ret
	
end:	

