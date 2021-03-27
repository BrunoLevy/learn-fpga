#include <femtorv32.h>

// Gets the number of cycles elapsed from device startup.
// IceStick version: internal counter has only 24 bits.

#ifdef ICE_STICK
uint64_t cycles() RV32_FASTCODE;
uint64_t cycles() {
  static uint64_t cycles_=0;
  static uint32_t last_cycles32_=0;
  uint32_t cycles32_;
  asm volatile ("rdcycle %0" : "=r"(cycles32_));
  int dcycle = cycles32_ - last_cycles32_;
  // Detect 24-bits counter overflow
  if(dcycle < 0) {
    dcycle += (1u << 24);
  }
  cycles_ += dcycle;
  last_cycles32_ = cycles32_;
  return cycles_;
}
#endif

