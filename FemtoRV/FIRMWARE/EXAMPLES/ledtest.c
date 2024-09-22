#include <femtorv32.h>
//#include <femtoGL.h>

int main() {

   int bits=0x3f;
   //GL_tty_init(GL_MODE_OLED);
   printf("femtorv32 LED pcf assignment check\n");
   for(;;) {

      IO_OUT(IO_LEDS, bits);
      printf("bits=%x\n", (int)bits);

      int c = getchar();
      if(c != 10 && c !=13) {
	 //putchar(c);
	 // printf("char=%d\n", (int)c);
         switch (c) {
         case '+':
           bits++;
           break;
         case '-':
           bits--;
           break;
         case '<':
           bits = bits << 1;
           break;
         case '>':
           bits = bits >> 1;
           break;
         default:
           putchar('?');
           break;
         }
         bits = bits & 0xff;
      } else {
	 putchar('\n');
	 putchar(']');
      }
   }
   return 0;
}

