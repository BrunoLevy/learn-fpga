#include <femtorv32.h>
//#include <femtoGL.h>

int main() {

   int bits=0x1f;
   //GL_tty_init(GL_MODE_OLED);
   printf("femtorv32 LED pcf assignment check\n");
   for(;;) {

      IO_OUT(IO_LEDS, bits);
      printf("bits=%x\n", (int)bits);
      bits++;
      bits &= 0x1f;

   }
   return 0;
}

