#include <femtorv32.h>

// é = 130
// smileys = 1,2

int main() {
   MAX7219_tty_init(); // redirect printf() to led matrix scroller   
   for(;;) {
      printf("Hello, RISC-V world \001 \002 \001 \002 ");
   }
   return 0;
}

