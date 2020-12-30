#include <femtorv32.h>

void milliwait(int time) {
   wait_cycles(time * 1000 * FEMTORV32_FREQ);
}

