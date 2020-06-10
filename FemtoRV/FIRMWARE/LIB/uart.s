.include "femtorv32.inc"
	
#################################################################################	
# NanoRv UART support
#################################################################################

.global	put_char
.type	put_char, @function
put_char:
        sw a0,IO_UART_TX_DATA(gp)
pcrx:	lw t0,IO_UART_TX_CNTL(gp)
	bnez t0,pcrx
	ret

.global	get_char
.type	get_char, @function
get_char:
        lw a0,IO_UART_RX_CNTL(gp)
        beqz a0,get_char
        lw a0,IO_UART_RX_DATA(gp)
	li t0, 10                  # <enter> generates CR/LF, we ignore LF.
	beq a0, t0, get_char
        ret 

.global	print_string
.type	print_string, @function
print_string:
        mv t0, a0
psl:	lbu t1, 0(t0)
	beqz t1,pseos
	sw t1,IO_UART_TX_DATA(gp)
psrx:	lw t1,IO_UART_TX_CNTL(gp)
	bnez t1,psrx
	add t0,t0,1
	j psl
pseos:  ret	

