#include <bb_max7219_text.h>

static uint8_t buff[16] = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}; 

void BB_MAX7219_shift() {
   for(int i=0; i<15; ++i) {
       if(i<8) {
	   BB_MAX7219(i+1, buff[i]);       	   
       }
       buff[i] = buff[i+1];
   }
   delay(60);
}


int BB_MAX7219_putchar(int c) {
   int i;
   if(c == 10) {
       BB_MAX7219_putchar(' ');
       BB_MAX7219_putchar(' ');
       return c;
   } 
   if(c == 13) {
       BB_MAX7219_putchar(' ');
       BB_MAX7219_putchar(' ');
       return c;
   }

   for(i=0; i<8; ++i) {
      buff[8+i] = font_8x8[8*c+i];
   }
   for(i=0; i<8; ++i) {
      BB_MAX7219_shift();
   }

   return c;
}

void BB_MAX7219_tty_init() {
   GL_set_font(&Font8x8);
   BB_MAX7219_init();
   for(int i=0; i<8; ++i) {
      BB_MAX7219(i+1, 0);
   }
    set_putcharfunc(BB_MAX7219_putchar);
}



