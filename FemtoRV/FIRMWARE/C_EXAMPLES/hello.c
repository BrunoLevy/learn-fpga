#include <femtorv32.h>

int main() {
   MAX2719_tty_init();
   for(;;) {
      printf("femtoRV32 says: hello, world !!\n");
      getchar();
   }
   return 0;
}

