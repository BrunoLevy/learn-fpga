#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

typedef unsigned int uint32;

/* Standard library */
extern void exit(int);
extern char get_char();
extern void put_char(char c);
extern void print_string(const char* s);
extern void print_dec(int val);
extern void print_hex_digits(unsigned int val, int digits);
extern void print_hex(unsigned int val);
extern void wait(); 

/* Memory-mapped IO */
#define IO_BASE      0x2000   /* Base address of memory-mapped IO                       */
#define IO_LEDS      0        /* 4 LSBs mapped to D1,D2,D3,D4                           */
#define IO_OLED_CNTL 4        /* OLED display control.                                  */
                              /*  wr: 01: reset low 11: reset high 00: normal operation */
                              /*  rd:  0: ready  1: busy                                */
#define IO_OLED_CMD     8     /* OLED display command. Only 8 LSBs used.                */
#define IO_OLED_DATA    12    /* OLED display data. Only 8 LSBs used.                   */
#define IO_UART_RX_CNTL 16    /* USB UART RX control. read: LSB bit 1 if data ready     */
#define IO_UART_RX_DATA 20    /* USB UART RX data (read)                                */
#define IO_UART_TX_CNTL 24    /* USB UART TX control. read: LSB bit 1 if busy           */
#define IO_UART_TX_DATA 28    /* USB UART TX data (write)                               */
#define IO_LEDMTX_CNTL  32    /* LED matrix control. read: LSB bit 1 if busy            */
#define IO_LEDMTX_DATA  36    /* LED matrix data (write)	                        */

#define IO_IN(port)       *(volatile uint32*)(IO_BASE + port)
#define IO_OUT(port,val)  *(volatile uint32*)(IO_BASE + port)=(val)
#define LEDS(val)         IO_OUT(IO_LEDS,val)

/* SSD1351 Oled display on 4-wire SPI bus */
extern void oled_init();
extern void oled_clear();
extern void oled_wait();
extern void oled0(uint32 cmd);
extern void oled1(uint32 cmd, uint32 arg1);
extern void oled2(uint32 cmd, uint32 arg1, uint32 arg2);
extern void oled3(uint32 cmd, uint32 arg1, uint32 arg2, uint32 arg3);

/* MAX2719 led matrix */
extern void MAX2719_init();
extern void MAX2719(uint32 address, uint32 value);

#endif
