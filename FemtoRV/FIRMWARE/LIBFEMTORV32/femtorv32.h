#ifndef H__FEMTORV32__H
#define H__FEMTORV32__H

#include "HardwareConfig_bits.h"
#include <stdint.h>

/* 
 * On the IceStick, code is entirely executed from the (slow) SPI flash,
 * except for functions marked as fastcode that will be loaded in the
 * (much faster) RAM (but use it wisely, you only got 7kB).
 * Other devices are sufficient RAM to load all the code.
 */
#if defined(ICE_STICK) || defined(ICE_BREAKER)
#define RV32_FASTCODE __attribute((section(".fastcode")))
#else
#define RV32_FASTCODE
#endif

/* Standard library */
extern int  printf(const char *fmt,...); /* supports %s, %d, %x */
extern void exit(int);
extern void abort();
extern int  getchar();
extern int  putchar(int c);
extern int  puts(const char* s);

/* Timing */
extern uint64_t cycles();            /* gets the number of cycles since last reset       (needs NRV_COUNTERS_64) */
extern uint64_t milliseconds();      /* gets the number of milliseconds since last reset (needs NRV_COUNTERS_64) */
extern void wait_cycles(int cycles); /* waits for a number of cycles.       */
extern void milliwait(int ms);       /* waits for a number of milliseconds. */
extern void microwait(int us);       /* waits for a number of microseconds. */
#define delay(ms) milliwait(ms)

/* System */

extern int filesystem_init(); /* 
			       * needs to be called to access files on SDCard (fopen(),fread()...) 
			       * returns 0 on success, non-zero on error.
			       */

extern int exec(const char* filename, int argc, char** argv);
                                       /* 
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
#define IO_MAX7219           IO_BIT_TO_OFFSET(IO_MAX7219_DAT_bit)
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
#define FEMTORV32_COUNTER_BITS    (IO_IN(IO_HW_CONFIG_CPUINFO) & 127)


/* SSD1331/SSD1351 Oled display on 4-wire SPI bus */

#if defined(SSD1351)
#define OLED_WIDTH  128
#define OLED_HEIGHT 128
#endif

#if defined(SSD1331)
#define OLED_WIDTH  96
#define OLED_HEIGHT 64
#endif

#ifndef OLED_WIDTH
#define OLED_WIDTH 0
#endif

#ifndef OLED_HEIGHT
#define OLED_HEIGHT 0
#endif

extern void oled_init();
extern void oled_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2);
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

/* Mapped SPI FLASH */
#define SPI_FLASH_BASE ((void*)(1 << 23))

/* FAT_IO_LIB */
#define USE_FILELIB_STDIO_COMPAT_NAMES
#define FAT_INLINE inline
#include <fat_io_lib/fat_filelib.h>

#endif
