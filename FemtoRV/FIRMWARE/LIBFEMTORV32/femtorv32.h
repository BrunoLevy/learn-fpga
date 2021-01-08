#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

#include "HardwareConfig_bits.h"
#include "FGA.h"

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

extern uint64_t cycles();            /* gets the number of cycles since last reset       (needs NRV_COUNTERS_64) */
extern uint64_t milliseconds();      /* gets the number of milliseconds since last reset (needs NRV_COUNTERS_64) */
extern void wait_cycles(int cycles); /* waits for a number of cycles.       */
extern void milliwait(int ms);       /* waits for a number of milliseconds. */
extern void microwait(int ns);       /* waits for a number of microseconds. */
#define delay(ms) milliwait(ms)

/* System */

extern int filesystem_init(); /* 
			       * needs to be called to access files on SDCard (fopen(),fread()...) 
			       * returns 0 on success, non-zero on error.
			       */

extern int exec(const char* filename); /* 
					* Executes a program from the SDCard. 
					* Returns a non-zero number on error.
					* does not return on success !
					* Supports risc-v elves (.elf) and
					* flat binaries (.bin).
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
extern uint8_t*  font_8x16;   /* 16 bytes per char. Each byte corresponds to a column.   */
extern uint8_t*  font_8x8;    /*  8 bytes per char. Each byte corresponds to a column.   */
extern uint32_t* font_5x6;    /*  4 bytes per char. 5 columns of 6 bits. bit 31=shift.   */
extern uint16_t* font_3x5;    /*  2 bytes per char. 3 columns of 5 bits.                 */

/* FemtoGL library */

/* Converts three R,G,B components (between 0 and 255) into a 16 bits color value for the OLED screen or FGA. */
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

extern int      FGA_mode;
extern uint16_t FGA_width;
extern uint16_t FGA_height;

extern void FGA_wait_vbl();
extern void FGA_clear();
extern void FGA_line(int x1, int y1, int x2, int y3, uint16_t color);
extern void FGA_fill_rect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color);
extern void FGA_fill_poly(int nb_pts, int* points, uint16_t color);


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


/********************* Memory-mapped IO *******************************************************/

#define IO_BASE      0x400000 /* Base address of memory-mapped IO */

/* Converts a memory-mapped register bit into the corresponding offset to be added to IO_BASE */
#define IO_BIT_TO_OFFSET(io_bit) (1 << (2+(io_bit)))  

/* All the memory-mapped hardware registers */
#define IO_LEDS              IO_BIT_TO_OFFSET(IO_LEDS_bit)
#define IO_SSD1351_CNTL      IO_BIT_TO_OFFSET(IO_SSD1351_CNTL_bit)
#define IO_SSD1351_CMD       IO_BIT_TO_OFFSET(IO_SSD1351_CMD_bit)
#define IO_SSD1351_DAT       IO_BIT_TO_OFFSET(IO_SSD1351_DAT_bit)
#define IO_SSD1351_DAT16     IO_BIT_TO_OFFSET(IO_SSD1351_DAT16_bit)
#define IO_UART_CNTL         IO_BIT_TO_OFFSET(IO_UART_CNTL_bit)
#define IO_UART_DAT          IO_BIT_TO_OFFSET(IO_UART_DAT_bit)
#define IO_MAX2719           IO_BIT_TO_OFFSET(IO_MAX2719_bit)
#define IO_SPI_FLASH         IO_BIT_TO_OFFSET(IO_SPI_FLASH_bit)
#define IO_SDCARD            IO_BIT_TO_OFFSET(IO_SDCARD_bit)
#define IO_BUTTONS           IO_BIT_TO_OFFSET(IO_BUTTONS_bit)
#define IO_FGA_CNTL          IO_BIT_TO_OFFSET(IO_FGA_CNTL_bit)
#define IO_FGA_DAT           IO_BIT_TO_OFFSET(IO_FGA_DAT_bit)    
#define IO_HW_CONFIG_RAM     IO_BIT_TO_OFFSET(IO_HW_CONFIG_RAM_bit)
#define IO_HW_CONFIG_DEVICES IO_BIT_TO_OFFSET(IO_HW_CONFIG_DEVICES_bit)
#define IO_HW_CONFIG_CPUINFO IO_BIT_TO_OFFSET(IO_HW_CONFIG_CPUINFO_bit)

#define IO_IN(port)       *(volatile uint32_t*)(IO_BASE + port)
#define IO_OUT(port,val)  *(volatile uint32_t*)(IO_BASE + port)=(val)
#define LEDS(val)         IO_OUT(IO_LEDS,val)

#define FEMTOSOC_HAS_DEVICE(bit)  (IO_IN(IO_HW_CONFIG_DEVICES) & (1 << bit))
#define FEMTORV32_FREQ           ((IO_IN(IO_HW_CONFIG_CPUINFO) >> 16) & 1023)
#define FEMTORV32_CPL             (IO_IN(IO_HW_CONFIG_CPUINFO) >> 26)

/* SSD1351 Oled display on 4-wire SPI bus */
extern void oled_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2);
extern void oled0(uint32_t cmd);
extern void oled1(uint32_t cmd, uint32_t arg1);
extern void oled2(uint32_t cmd, uint32_t arg1, uint32_t arg2);
extern void oled3(uint32_t cmd, uint32_t arg1, uint32_t arg2, uint32_t arg3);

/* 
 * low-level functions to send data to the OLED display and FGA
 *    First, call oled_write_window()
 *    Then send all the pixels using one of the three forms of OLED_WRITE_DATA
 */ 

/*
 * The magic of 1-hot encoding for memory-mapped hw registers: one can
 * write in two register simultaneously by setting both bits in the address.
 * Here we send the same graphic byte to the OLED display and FGA graphic board,
 * so that graphic programs work on both.
 */ 

#define IO_GFX_DAT (IO_SSD1351_DAT16 | IO_FGA_DAT) 
#define OLED_WRITE_DATA_UINT16(RGB) IO_OUT(IO_GFX_DAT,(RGB)) 
#define OLED_WRITE_DATA_RGB(R,G,B)  OLED_WRITE_DATA_UINT16(GL_RGB(R,G,B))

/* MAX7219 led matrix */
extern void MAX7219_init();
extern void MAX7219(uint32_t address, uint32_t value);

#define MIN(x,y) (((x) < (y)) ? (x) : (y))
#define MAX(x,y) (((x) > (y)) ? (x) : (y))
#define SGN(x)   (((x) > (0)) ? 1 : ((x) ? -1 : 0))

/* 
 * Femto Graphics Adapter 
 * 
 * Mode 0:
 * Flat 320x200x16bpp buffer, write-only 
 * Color encoding same as SSD1351 (use GL_RGB() to encode colors)
 */
#define FGA_BASEMEM (void*)(1 << 21)

static inline FGA_setpixel_RGB(int x, int y, uint8_t R, uint8_t G, uint8_t B) {
  FGA_setpixel(x,y,GL_RGB(R,G,B));
}

void FGA_setmode(int mode);

static inline FGA_setpalette(int index, uint8_t R, uint8_t G, uint8_t B) {
   IO_OUT(IO_FGA_CNTL, 1 | (index << 8) | (R << 16));
   IO_OUT(IO_FGA_CNTL, 2 | (index << 8) | (G << 16));
   IO_OUT(IO_FGA_CNTL, 3 | (index << 8) | (B << 16));   
}

/* Simple "GUI" functions */
int GUI_prompt(char* title, char** options);

/* Mapped SPI FLASH */
#define SPI_FLASH_BASE ((void*)(1 << 23))

/* FAT_IO_LIB */
#define USE_FILELIB_STDIO_COMPAT_NAMES
#define FAT_INLINE inline
#include <fat_io_lib/fat_filelib.h>

#endif
