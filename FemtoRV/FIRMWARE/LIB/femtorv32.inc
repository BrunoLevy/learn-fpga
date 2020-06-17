#################################################################################

# Mapped IO constants

.equ IO_BASE,      0x2000   # Base address of memory-mapped IO
.equ IO_LEDS,      0        # 4 LSBs mapped to D1,D2,D3,D4
.equ IO_OLED_CNTL, 4        # OLED display control.
                            #  wr: 01: reset low 11: reset high 00: normal operation
                            #  rd:  0: ready  1: busy
.equ IO_OLED_CMD,  8        # OLED display command. Only 8 LSBs used.
.equ IO_OLED_DATA, 12       # OLED display data. Only 8 LSBs used.
.equ IO_UART_RX_CNTL, 16    # USB UART RX control. read: LSB bit 1 if data ready
.equ IO_UART_RX_DATA, 20    # USB UART RX data (read)
.equ IO_UART_TX_CNTL, 24    # USB UART TX control. read: LSB bit 1 if busy
.equ IO_UART_TX_DATA, 28    # USB UART TX data (write)
.equ IO_LEDMTX_CNTL,  32    # LED matrix control. read: LSB bit 1 if busy
.equ IO_LEDMTX_DATA,  36    # LED matrix data (write)	
	
################################################################################
