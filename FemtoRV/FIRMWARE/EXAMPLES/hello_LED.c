#include <femtorv32.h>

int main() {
   MAX7219_tty_init(); // redirect printf() to led matrix scroller   
   for(;;) {
//      printf("Hello, RISC-V world !!! ");
//      printf("Vive le Lyc%ce Poincar%c de Nancy !!! ....",130,130);
//      printf("Hello, LiteX world !!! ");
        printf("T%cl%ccom Nancy RULZ !!!",130,130);
   }
   return 0;
}

