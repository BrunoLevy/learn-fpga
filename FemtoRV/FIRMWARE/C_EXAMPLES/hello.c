#include <femtorv32.h>

int main() {
   MAX2719_tty_init();
   // femtosoc_tty_init();
   for(;;) {
      printf("Hello, world !!\n");
//    getchar();
   }
   return 0;
}

