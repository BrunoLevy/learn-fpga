#include <femtorv32.h>

static uint8_t buff[16] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

void MAX2719_shift() {
   for(int i=0; i<15; ++i) {
       if(i<8) {
	   MAX2719(i+1, buff[i]);       	   
       }
       buff[i] = buff[i+1];
   }
   delay(30);
}


int MAX2719_putchar(int c) {
   int i;
   if(c == 10) {
       MAX2719_putchar(' ');
       MAX2719_putchar(' ');
       return c;
   } 
   if(c == 13) {
       MAX2719_putchar(' ');
       MAX2719_putchar(' ');
       return c;
   }

   for(i=0; i<8; ++i) {
      buff[8+i] = font_8x8[8*c+i];
   }
   for(i=0; i<8; ++i) {
      MAX2719_shift();
   }

   return c;
}

void MAX2719_tty_init() {
   MAX2719_init();
   for(int i=0; i<8; ++i) {
      MAX2719(i+1, 0);
   }
    set_putcharfunc(MAX2719_putchar);
}



