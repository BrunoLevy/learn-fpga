#include <stdio.h>
#include <stdint.h>

#define SPI_FLASH_BASE ((uint32_t*)(1 << 23))

int main() {
   for(;;) {
      for(int i=0; i<40; ++i) {
	 uint32_t word = SPI_FLASH_BASE[i];
	 char* c = (char*)&word;
	 printf("%d 0x%x %c%c%c%c\n", i, word, c[0],c[1],c[2],c[3]);
      }
      printf("\n");
      printf("\n");      
   }
   
}
