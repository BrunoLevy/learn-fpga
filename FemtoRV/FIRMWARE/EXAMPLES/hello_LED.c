#include <femtorv32.h>

// é = 130
// smileys = 1,2

int main() {
   MAX7219_tty_init(); // redirect printf() to led matrix scroller   
   for(;;) {
      printf("Hello, RISC-V world !!! %c %c %c %c ",1,2,1,2);
   }
   return 0;
}

