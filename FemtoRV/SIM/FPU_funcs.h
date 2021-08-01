// FPU: for now simulated / implemented in C++
#include <stdint.h>

void print_float(uint32_t x);

uint32_t FMADD(uint32_t x, uint32_t y, uint32_t z);
uint32_t FMSUB(uint32_t x, uint32_t y, uint32_t z);
uint32_t FNMADD(uint32_t x, uint32_t y, uint32_t z);
uint32_t FNMSUB(uint32_t x, uint32_t y, uint32_t z);

uint32_t FADD(uint32_t x, uint32_t y);
uint32_t FSUB(uint32_t x, uint32_t y);
uint32_t FMUL(uint32_t x, uint32_t y);
uint32_t FDIV(uint32_t x, uint32_t y);
uint32_t FSQRT(uint32_t x);

uint32_t FSGNJ(uint32_t x, uint32_t y);
uint32_t FSGNJN(uint32_t x, uint32_t y);
uint32_t FSGNJX(uint32_t x, uint32_t y);
uint32_t FMIN(uint32_t x, uint32_t y);
uint32_t FMAX(uint32_t x, uint32_t y);

uint32_t FCVTWS(uint32_t x);
uint32_t FCVTWUS(uint32_t x);

uint32_t FEQ(uint32_t x, uint32_t y);
uint32_t FLT(uint32_t x, uint32_t y);
uint32_t FLE(uint32_t x, uint32_t y);

uint32_t FCLASS(uint32_t x);
uint32_t FCVTSW(uint32_t x);
uint32_t FCVTSWU(uint32_t x);
