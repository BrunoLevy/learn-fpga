#include <femtorv32.h>

int main() {
   MAX2719_tty_init();
   // femtosoc_tty_init();
   for(;;) {
      printf("Hello world !!\n Let me introduce myself, I am FemtoRV32, one of the smallest RISC-V cores\n");
//    getchar();
   }
   return 0;
}

