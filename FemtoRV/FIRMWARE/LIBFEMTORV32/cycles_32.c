#include <femtorv32.h>

// Gets the number of cycles elapsed from device startup.
// This version for processors that do not have 64-bits
// tick counter. 

#ifndef CYCLES_64
uint64_t cycles() RV32_FASTCODE;
uint64_t cycles() {
  static uint32_t cycles_lap_=0;
  static uint64_t cycles_=0;
  static uint32_t last_cycles32_=0;
  uint32_t cycles32_;

  if(cycles_lap_ == 0) {
    cycles_lap_ = FEMTORV32_COUNTER_BITS;
    if(cycles_lap_ == 32) {
      cycles_lap_ = ~0u;
    } else {
      cycles_lap_ = 1u << cycles_lap_;
    }
  }

  
  asm volatile ("rdcycle %0" : "=r"(cycles32_));
  // Detect counter overflow
  if(cycles32_ < last_cycles32_) {
    cycles_ += cycles_lap_;
  }
  cycles_ += cycles32_;
  cycles_ -= last_cycles32_;
  last_cycles32_ = cycles32_;
  return cycles_;
}
#endif

