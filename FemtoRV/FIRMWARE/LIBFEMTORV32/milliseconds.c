#include <femtorv32.h>

uint32_t milliseconds() {
    // TODO: solve problem with 64-bits division
    uint32_t freq = (IO_IN(IO_DEVICES_FREQ)) >> 16;
    uint32_t cyc = (uint32_t)cycles();
    return (cyc * 1000) / freq;
}
