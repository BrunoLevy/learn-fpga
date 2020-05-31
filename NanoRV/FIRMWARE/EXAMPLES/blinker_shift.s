# Blinker example, using the shift instruction

.section .text
.globl _start
.equ IO_BASE,      0x1000   # Base address of memory-mapped IO
.equ IO_LEDS,      0        # 4 LSBs mapped to D1,D2,D3,D4
	
_start:
        li   gp,0x1000
	li   t1,0
	li   t2,15       
loop:	addi t1,t1,1
	call show
	bne  t0,t2,loop
	j    end

	
show:   srli t0,t1,18
	sw t0,IO_LEDS(gp)
	ret
	
end:	

