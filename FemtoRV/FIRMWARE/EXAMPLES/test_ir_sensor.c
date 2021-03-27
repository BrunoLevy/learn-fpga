#include <femtorv32.h>

static inline int ir_status() {
   return !(IO_IN(IO_LEDS) & 64);
}

void test_irda() RV32_FASTCODE;
void test_irda() {
   for(;;) {
      printf("%c",ir_status() ? '*' : ' ');
   }
}

int main() {
   femtosoc_tty_init();
   test_irda();
}
