#include <femtorv32.h>

static inline int ir_status() {
   return !(IO_IN(IO_LEDS) & 16);
}

void test_irda() RV32_FASTCODE;
void test_irda() {
   for(;;) {
      int status = !(IO_IN(IO_LEDS) & 16);
      printf("%c",status ? '*' : ' ');
   }
}

int main() {
   femtosoc_tty_init();
   test_irda();
}
