
#include <femtorv32.h>

int main() {
   int i=0;
   for(;;) {
      i=i+1;
      LEDS(i >> 13);
   }
}
