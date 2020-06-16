#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

typedef unsigned char  uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int   uint32_t;

/* Standard library */
extern void exit(int);
extern void abort();
extern int  getchar();
extern int  putchar(int c);
extern int  puts(const char* s);
extern int  printf(const char *fmt,...); /* supports %s, %d, %x */

/* Other functions */
extern void delay(int ms);    /* waits an (approximate) number of milliseconds.         */
extern int  random();

/* Virtual I/O */
typedef int (*putcharfunc_t)(int);
typedef int (*getcharfunc_t)(void);
void set_putcharfunc(putcharfunc_t fptr);
void set_getcharfunc(getcharfunc_t fptr);

/* Specialized print functions (but one can use printf() instead) */
extern void print_string(const char* s);
extern void print_dec(int val);
extern void print_hex_digits(unsigned int val, int digits);
extern void print_hex(unsigned int val);

/* Font maps */
extern uint8_t*  font_8x8;    /* 8 bytes per char. Each byte corresponds to a column.   */
extern uint32_t* font_5x6;    /* 4 bytes per char. 5 columns of 6 bits. bit 31=shift.   */
extern uint16_t* font_3x5;    /* 2 bytes per char. 3 columns of 5 bits.                 */

/* FemtoGL library */

#define GL_RGB(R,G,B) ((((((R) & 0xF8) << 2) | ((G) & 0xF8)) << 6) | ((B) >> 3))

extern uint16_t GL_fg;
extern uint16_t GL_bg;

extern void GL_set_fg(uint8_t r, uint8_t g, uint8_t b);
extern void GL_set_bg(uint8_t r, uint8_t g, uint8_t b);
extern void GL_init();
extern void GL_clear();
extern void GL_fill_rect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color);
extern void GL_setpixel(int x, int y, uint16_t color);
extern void GL_line(int x1, int y1, int x2, int y3, uint16_t color);

void GL_tty_init();           /* Initializes OLED screen and redirects output to it.    */
void GL_tty_goto_xy(int X, int Y);
int  GL_putchar(int c);
void GL_putchar_xy(int x, int y, char c);


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

#define IO_IN(port)       *(volatile uint32_t*)(IO_BASE + port)
#define IO_OUT(port,val)  *(volatile uint32_t*)(IO_BASE + port)=(val)
#define LEDS(val)         IO_OUT(IO_LEDS,val)

/* SSD1351 Oled display on 4-wire SPI bus */
extern void oled_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2);
extern void oled_wait();
extern void oled0(uint32_t cmd);
extern void oled1(uint32_t cmd, uint32_t arg1);
extern void oled2(uint32_t cmd, uint32_t arg1, uint32_t arg2);
extern void oled3(uint32_t cmd, uint32_t arg1, uint32_t arg2, uint32_t arg3);

/* MAX2719 led matrix */
extern void MAX2719_init();
extern void MAX2719(uint32_t address, uint32_t value);

#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#define SGN(x)   (((x) > (0)) ? 1 : ((x) ? -1 : 0))

#endif
