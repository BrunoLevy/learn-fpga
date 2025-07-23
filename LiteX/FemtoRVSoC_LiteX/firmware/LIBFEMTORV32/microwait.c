#include <femtorv32.h>

void microwait(int time) {
   if(time) {
      wait_cycles(time * FEMTORV32_FREQ);
   }
}

