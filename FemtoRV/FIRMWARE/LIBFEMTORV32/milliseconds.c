#include <femtorv32.h>

uint32_t milliseconds() {
    // TODO: solve problem with 64-bits division
    /* 
    uint32_t freq = FEMTORV32_FREQ;
    uint32_t cyc = (uint32_t)cycles();
    return (cyc * 1000) / freq;
    */
   uint64_t freq = (uint64_t)FEMTORV32_FREQ;
   uint64_t cyc  = (uint64_t)cycles();
   return (uint32_t)((cyc * 1000) / freq);
}
