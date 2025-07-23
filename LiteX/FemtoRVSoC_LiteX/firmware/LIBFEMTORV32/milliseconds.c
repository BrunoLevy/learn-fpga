#include <femtorv32.h>

uint64_t milliseconds() {
   uint64_t freq = (uint64_t)FEMTORV32_FREQ;
   uint64_t cyc  = (uint64_t)cycles();
   return cyc / (freq * 1000);
}
