#include <femtorv32.h>

void wait_cycles(int nb_cycles) {
  uint64_t lim = cycles() + (uint64_t)nb_cycles;
  while(cycles()<lim);
}
