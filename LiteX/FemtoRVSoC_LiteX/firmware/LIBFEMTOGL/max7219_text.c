#include <femtoGL.h>

static uint8_t buff[16] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}; 

void MAX7219_shift() {
   for(int i=0; i<15; ++i) {
       if(i<8) {
	   MAX7219(i+1, buff[i]);       	   
       }
       buff[i] = buff[i+1];
   }
   delay(60);
}


int MAX7219_putchar(int c) {
   int i;
   if(c == 10) {
       MAX7219_putchar(' ');
       MAX7219_putchar(' ');
       return c;
   } 
   if(c == 13) {
       MAX7219_putchar(' ');
       MAX7219_putchar(' ');
       return c;
   }

   for(i=0; i<8; ++i) {
      buff[8+i] = font_8x8[8*c+i];
   }
   for(i=0; i<8; ++i) {
      MAX7219_shift();
   }

   return c;
}

void MAX7219_tty_init() {
   MAX7219_init();
   for(int i=0; i<8; ++i) {
      MAX7219(i+1, 0);
   }
    set_putcharfunc(MAX7219_putchar);
}



