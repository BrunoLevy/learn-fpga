#include "io.h"

#define SPI_FLASH_BASE ((char*)(1 << 23))

int main()  {
   for(int i=0; i<16; ++i) {
      IO_OUT(IO_LEDS,i);
      int lo = (int)SPI_FLASH_BASE[2*i  ];
      int hi = (int)SPI_FLASH_BASE[2*i+1];
      print_hex_digits((hi << 8) | lo,4); // print four hexadecimal digits
      printf(" ");
   }
   printf("\n");
}
