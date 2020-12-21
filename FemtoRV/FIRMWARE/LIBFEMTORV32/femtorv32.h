#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

typedef unsigned char          uint8_t;
typedef unsigned short         uint16_t;
typedef unsigned int           uint32_t;
typedef unsigned long long int uint64_t;
typedef char                   int8_t;
typedef short                  int16_t;
typedef int                    int32_t;
typedef long long int          int64_t;
typedef unsigned int           size_t;

/* Standard library */
extern int  printf(const char *fmt,...); /* supports %s, %d, %x */
extern void exit(int);
extern void abort();
extern int  getchar();
extern int  putchar(int c);
extern int  puts(const char* s);

extern void delay(int ms);     /* waits an (approximate) number of milliseconds. */
extern void microwait(int ns); /* waits an (approximate) number of microseconds.  */
extern uint64_t cycles(); /* gets the number of cycles since last reset (needs NRV_COUNTERS_64) */

/* System */

extern int exec(const char* filename); /* Executes a program from the SDCard. 
					* Returns a non-zero number on error.
					* does not return on success !
					*/
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

/* SDCard */
int sd_init(); /* Return 0 on success, non-zero on failure */
int sd_readsector(uint32_t sector, uint8_t* buffer, uint32_t sector_count); /* 1:success, 0:failure*/
int sd_writesector(uint32_t sector, uint8_t* buffer, uint32_t sector_count); /* 1:success, 0:failure*/

/* Font maps */
extern uint8_t*  font_8x8;    /* 8 bytes per char. Each byte corresponds to a column.   */
extern uint32_t* font_5x6;    /* 4 bytes per char. 5 columns of 6 bits. bit 31=shift.   */
extern uint16_t* font_3x5;    /* 2 bytes per char. 3 columns of 5 bits.                 */

/* FemtoGL library */

/* Converts three R,G,B components (between 0 and 255) into a 16 bits color value for the OLED screen. */
#define GL_RGB(R,G,B) ((((((R) & 0xF8) << 5) | ((G) & 0xF8)) << 3) | ((B) >> 3))

extern uint16_t GL_fg;
extern uint16_t GL_bg;

extern void GL_set_fg(uint8_t r, uint8_t g, uint8_t b);
extern void GL_set_bg(uint8_t r, uint8_t g, uint8_t b);
extern void GL_init();
extern void GL_clear();
extern void GL_fill_rect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color);
extern void GL_setpixel(int x, int y, uint16_t color);
extern void GL_line(int x1, int y1, int x2, int y3, uint16_t color);
extern void GL_fill_poly(int nb_pts, int* points, uint16_t color);

#define GL_POLY_LINES 1
#define GL_POLY_FILL  2
extern int gl_polygon_mode;
#define GL_polygon_mode(mode) gl_polygon_mode = (mode);

#define GL_FRONT_FACE     1
#define GL_BACK_FACE      2
#define GL_FRONT_AND_BACK 3
extern int gl_culling_mode;
#define GL_culling_mode(mode) gl_culling_mode = (mode);

void femtosoc_tty_init();     /* Initializes tty (putchar()) based on present devices.
			       * Note: pulls all fonts (eats up a consequent part of the
			       * available 6Kb... Do not use systematically.
			       */
void MAX7219_tty_init();      /* Initializes led matrix and redirects output to it.     */
void GL_tty_init();           /* Initializes OLED screen and redirects output to it.    */
void GL_tty_goto_xy(int X, int Y);
int  GL_putchar(int c);
void GL_putchar_xy(int x, int y, char c);


/* Memory-mapped IO */
#define IO_BASE      0x400000 /* Base address of memory-mapped IO                       */
#define IO_LEDS      4        /* 4 LSBs mapped to D1,D2,D3,D4                           */
#define IO_OLED_CNTL 8        /* OLED display control.                                  */
                              /*  wr: 01: reset low 11: reset high 00: normal operation */
                              /*  rd:  0: ready  1: busy                                */
#define IO_OLED_CMD     16    /* OLED display command. Only 8 LSBs used.                */
#define IO_OLED_DATA    32    /* OLED display data. Only 8 LSBs used.                   */
#define IO_DEVICES_FREQ 64    /* r: devices (16 LSBs) and frequency (16 MSBs)           */
#define IO_UART_DATA    128   /* USB UART RX data (read/write)                          */
#define IO_RAM          256   /* r: Installed RAM                                       */
#define IO_LEDMTX_DATA  512   /* LED matrix data (write)	                        */
#define IO_SPI_FLASH   1024   /* Onboard SPI flash, can be used to stored data          */
#define IO_SPI_SDCARD  2048   /* ULX3S SDCard                                           */
#define IO_BUTTONS     4096   /* ULX3S buttons                                          */

/* To test the presence of a device, use IO_IN(IO_DEVICES_FREQ) & (1 << XXXX_BIT) */
#define IO_DEVICE_LEDS_BIT      0  
#define IO_DEVICE_SSD1351_BIT   1  
#define IO_DEVICE_UART_BIT      5 
#define IO_DEVICE_MAX2719_BIT   7
#define IO_DEVICE_SPI_FLASH_BIT 8
#define IO_DEVICE_SDCARD_BIT    9
#define IO_DEVICE_BUTTONS_BIT   10

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

/* MAX7219 led matrix */
extern void MAX7219_init();
extern void MAX7219(uint32_t address, uint32_t value);

#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#define SGN(x)   (((x) > (0)) ? 1 : ((x) ? -1 : 0))

#define USE_FILELIB_STDIO_COMPAT_NAMES
#define FAT_INLINE inline
#include <fat_io_lib/fat_filelib.h>

#endif
