/*****************************************************************/
#include "FPU_funcs.h"
#include <cstdio>
#include <cmath>

union IEEE754 {
  uint32_t i;  
  float f;
  struct {
    unsigned int mant:23;
    unsigned int exp:8;
    unsigned int sign:1;
  } bits;
};


inline float int_to_float(uint32_t x) {
  IEEE754 xx;
  xx.i = x;
  return xx.f;
}

inline uint32_t float_to_int(float x) {
  IEEE754 xx;
  xx.f = x;
  return xx.i;
}

void print_float(uint32_t x) {
  printf("%f\n",int_to_float(x));
}

uint32_t FMADD(uint32_t x, uint32_t y, uint32_t z) {
  return float_to_int(int_to_float(x)*int_to_float(y)+int_to_float(z));
}

uint32_t FMSUB(uint32_t x, uint32_t y, uint32_t z) {
  return float_to_int(int_to_float(x)*int_to_float(y)-int_to_float(z));  
}

uint32_t FNMADD(uint32_t x, uint32_t y, uint32_t z) {
  return float_to_int(-int_to_float(x)*int_to_float(y)+int_to_float(z));
}

uint32_t FNMSUB(uint32_t x, uint32_t y, uint32_t z) {
  return float_to_int(-int_to_float(x)*int_to_float(y)-int_to_float(z));  
}

uint32_t FADD(uint32_t x, uint32_t y) {
  return float_to_int(int_to_float(x)+int_to_float(y));
}

uint32_t FSUB(uint32_t x, uint32_t y) {
  return float_to_int(int_to_float(x)-int_to_float(y));
}

uint32_t FMUL(uint32_t x, uint32_t y) {
  return float_to_int(int_to_float(x)*int_to_float(y));
}

uint32_t FDIV(uint32_t x, uint32_t y) {
  return float_to_int(int_to_float(x)/int_to_float(y));
}

uint32_t FSQRT(uint32_t x) {
  return float_to_int(sqrtf(int_to_float(x)));
}

uint32_t FSGNJ(uint32_t x, uint32_t y) {
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = yy.bits.sign;
  return xx.i;
}

uint32_t FSGNJN(uint32_t x, uint32_t y) {
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = !yy.bits.sign;
  return xx.i;
}

uint32_t FSGNJX(uint32_t x, uint32_t y) {
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = xx.bits.sign ^ yy.bits.sign;
  return xx.i;
}

uint32_t FMIN(uint32_t x, uint32_t y) {
  return float_to_int(fmin(int_to_float(x),int_to_float(y)));
}

uint32_t FMAX(uint32_t x, uint32_t y) {
  return float_to_int(fmax(int_to_float(x),int_to_float(y)));  
}

uint32_t FCVTWS(uint32_t x) {
  return uint32_t(int32_t(int_to_float(x)));  
}

uint32_t FCVTWUS(uint32_t x) {
  return uint32_t(int_to_float(x));
}

uint32_t FEQ(uint32_t x, uint32_t y) {
  return (int_to_float(x) == int_to_float(y));
}

uint32_t FLT(uint32_t x, uint32_t y) {
  return (int_to_float(x) < int_to_float(y));
}

uint32_t FLE(uint32_t x, uint32_t y) {
  return (int_to_float(x) <= int_to_float(y));
}

uint32_t FCLASS(uint32_t x) {
  printf("FCLASS - not implemented yet\n");
  return 0;
}

uint32_t FCVTSW(uint32_t x) {
  return int_to_float(float(int32_t(x)));
}

uint32_t FCVTSWU(uint32_t x) {
  return int_to_float(float(x));
}
