#include <femtorv32.h>

int main() {

   int count=0;
   printf("femtorv32 alive check\n");
   for(;;) {
      IO_OUT(IO_LEDS, 1);
      delay(400);
      printf("alive=%x\n", count++);
      IO_OUT(IO_LEDS, 0);
      delay(400);
   }
   return 0;
}

