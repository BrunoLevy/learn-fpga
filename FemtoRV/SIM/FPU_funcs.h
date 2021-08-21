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

/*******************************************/

uint32_t CHECK_FMADD(uint32_t result, uint32_t x, uint32_t y, uint32_t z);
uint32_t CHECK_FMSUB(uint32_t result, uint32_t x, uint32_t y, uint32_t z);
uint32_t CHECK_FNMADD(uint32_t result, uint32_t x, uint32_t y, uint32_t z);
uint32_t CHECK_FNMSUB(uint32_t result, uint32_t x, uint32_t y, uint32_t z);

uint32_t CHECK_FADD(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FSUB(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FMUL(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FDIV(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FSQRT(uint32_t result, uint32_t x);

uint32_t CHECK_FSGNJ(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FSGNJN(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FSGNJX(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FMIN(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FMAX(uint32_t result, uint32_t x, uint32_t y);

uint32_t CHECK_FCVTWS(uint32_t result, uint32_t x);
uint32_t CHECK_FCVTWUS(uint32_t result, uint32_t x);

uint32_t CHECK_FEQ(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FLT(uint32_t result, uint32_t x, uint32_t y);
uint32_t CHECK_FLE(uint32_t result, uint32_t x, uint32_t y);

uint32_t CHECK_FCLASS(uint32_t result, uint32_t x);
uint32_t CHECK_FCVTSW(uint32_t result, uint32_t x);
uint32_t CHECK_FCVTSWU(uint32_t result, uint32_t x);
