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

