#include <femtorv32.h>

int main() {
   femtosoc_tty_init();
   for(;;) {
      printf("Hello, world !!\n");
//    getchar();
   }
   return 0;
}

