.include "femtorv32.inc"
	
#################################################################################	
# NanoRv UART support
#################################################################################

.global	UART_putchar
.type	UART_putchar, @function
UART_putchar:
        sw a0,IO_UART_TX_DATA(gp)
pcrx:	lw t0,IO_UART_TX_CNTL(gp)
	bnez t0,pcrx
	ret

.global	UART_getchar
.type	UART_getchar, @function
UART_getchar:
        lw a0,IO_UART_RX_CNTL(gp)
        beqz a0,UART_getchar
        lw a0,IO_UART_RX_DATA(gp)
	li t0, 10                  # <enter> generates CR/LF, we ignore LF.
	beq a0, t0, UART_getchar
        ret 

#.global	print_string
#.type	print_string, @function
#print_string:
#        mv t0, a0
#psl:	lbu t1, 0(t0)
#	beqz t1,pseos
#	sw t1,IO_UART_TX_DATA(gp)
#psrx:	lw t1,IO_UART_TX_CNTL(gp)
#	bnez t1,psrx
#	add t0,t0,1
#	j psl
#pseos:  ret	

#.global	puts
#.type	puts, @function
#puts:	add sp,sp,-4
#        sw ra, 0(sp)	
#        call print_string
#	li   a0, 13
#	call putchar
#	li   a0, 10
#	call putchar
#	lw ra, 0(sp)
#	add sp,sp,4
#       ret
