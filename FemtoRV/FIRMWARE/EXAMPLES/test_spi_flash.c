/*
 * Reads data bytes stored in the SPI FLASH memory.
 * 1. Create a file "hello.txt" with "Hello, world !" in it.
 * 2. On ICEstick: iceprog -o 1M hello.txt
 *    On ULX3S:  cp hello.txt hello.omg
 *               ujprog -j flash -f 1048576 hello.img
 *   (using latest version of ujprog compiled from https://github.com/kost/fujprog)
 */

#include <femtorv32.h>

#define BUSY 256

int get_spi_byte(int addr) {
   int result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   IO_OUT(IO_SPI_FLASH, addr);
   result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   return result & 255;
}

void printb(int x) {
    for(int i=7; i>=0; i--) {
	putchar((x & (1 << i)) ? '1' : '0');
    }
}

int main() {
   int addr = 1024*1024;
   int data;
   GL_tty_init(); // uncomment if using OLED display instead of tty output.
   printf("Testing SPI flash\n");
   for(int i=0; i<14; ++i) {
      data = get_spi_byte(addr);
      printf("%x:",data);
      printb(data);
      putchar(':');
      putchar(data);
      printf("\n");
      ++addr;
   }
   exit(0); // femtOS does not properly exit programs, so exit() is needed (to be fixed)
}
