
#include <femtorv32.h>

int main() {
   
   femtosoc_tty_init();
   GL_putchar('H');
   GL_putchar('e');
   GL_putchar('l');
   GL_putchar('l');
// GL_putchar('o');   
   
//  printf("Hello, world!!\n");

   int i=0;
   for(;;) {
      i=i+1;
      LEDS(i >> 13);
   }
   
   
//   asm("li gp,0x400000");
//   asm("li sp,6144");

/*   
   MAX7219_init();
   MAX7219_putchar('A');
 */
   
/*   
   MAX7219_init();
   MAX7219(1,1);
   MAX7219(2,2);
   MAX7219(3,4);
   MAX7219(4,8);
   MAX7219(5,16);
   MAX7219(6,32);
   MAX7219(7,64);
   MAX7219(8,128);
  */

/*   
   GL_init();
   oled_write_window(0,0,127,127);
   for(int y=0; y<128; ++y) 
     for(int x=0; x<128; ++x) 
       IO_OUT(IO_SSD1351_DAT16,GL_RGB(x<<1, (x*y)&255, y<<1));

 */
   
//   int i=0;
   for(;;) {
      i=i+1;
      LEDS(i >> 13);
   }
}
