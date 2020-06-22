#include <femtorv32.h>

#define READY 256
#define VALID 512

int get_spi_byte(int addr) {
   int result = 0;
   while(!(result & READY)) {
       result = IO_IN(IO_SPI_FLASH);       
   }
   IO_OUT(IO_SPI_FLASH, addr);
   result = 0;
   while(!(result & VALID)) {
       result = IO_IN(IO_SPI_FLASH);
   }
   return result & 255;
}


int main() {
   int addr = 1024*1024;
   int data;
//   GL_tty_init(); // uncomment if using OLED display instead of tty output.
   printf("Testing SPI flash\n");
   for(int i=0; i<256; ++i) {
      data = get_spi_byte(addr);
      printf("%x:%x\n",addr,data);
      ++addr;
      delay(100);
   }
   return 0;
}
