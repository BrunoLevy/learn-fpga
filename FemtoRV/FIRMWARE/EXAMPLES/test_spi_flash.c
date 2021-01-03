/*
 * Reads data bytes stored in the SPI FLASH memory.
 * 1. Create a file "hello.txt" with "Hello, world !" in it.
 * 2. On ICEstick: iceprog -o 1M hello.txt
 *    On ULX3S:  cp hello.txt hello.omg
 *               ujprog -j flash -f 1048576 hello.img
 *   (using latest version of ujprog compiled from https://github.com/kost/fujprog)
 */

#include <femtorv32.h>

// Two different modes for accessing the SPI flash, depends
// on what's configured in RTL/femtosoc_config.v

// Access through mapped IO register: read bytes one by one
int get_spi_byte_io(int addr) {
   IO_OUT(IO_SPI_FLASH, addr);
   return IO_IN(IO_SPI_FLASH);
}

// Access through mapped address space
int get_spi_byte_mapped(int addr) {
  addr -= (1024*1024);
  union {
    uint32_t word;
    uint8_t bytes[4];
  } u;
  u.word = ((uint32_t*)SPI_FLASH_BASE)[addr >> 2];
  return u.bytes[addr & 3];
}

void printb(int x) {
    for(int i=7; i>=0; i--) {
	putchar((x & (1 << i)) ? '1' : '0');
    }
}

int main() {
  
  // Test whether mapped memory space is activated
  int mapped = FEMTOSOC_HAS_DEVICE(IO_SPI_FLASH_bit);
  
  int addr = 1024*1024;
  int data;
  GL_tty_init(); // uncomment if using OLED display instead of tty output.
  printf("Testing SPI flash\n");
  for(int i=0; i<14; ++i) {
    data = mapped ? get_spi_byte_mapped(addr) : get_spi_byte_io(addr) ;
    printf("%x:",data);
    printb(data);
    putchar(':');
    putchar(data);
    printf("\n");
    ++addr;
  }
  return 0;
}
