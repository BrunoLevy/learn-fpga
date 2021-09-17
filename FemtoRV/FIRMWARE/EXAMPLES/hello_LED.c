#include <femtorv32.h>

int main() {
   MAX7219_tty_init(); // redirect printf() to led matrix scroller   
   for(;;) {
//      printf("Hello, RISC-V world !!! ");
//      printf("Hello, Symposium on Geometry Processing 2021 !!! ");/
      printf("Hello Telecom Nancy ......");
   }

   return 0;
}

