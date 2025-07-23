#include <stdint.h>

#define IO_BASE       0x400000
#define IO_LEDS       4
#define IO_UART_DAT   8
#define IO_UART_CNTL  16

#define IO_IN(port)       *(volatile uint32_t*)(IO_BASE + port)
#define IO_OUT(port,val)  *(volatile uint32_t*)(IO_BASE + port)=(val)

