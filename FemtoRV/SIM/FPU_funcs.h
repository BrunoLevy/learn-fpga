/*****************************************************************/
// FPU: for now simulated / implemented in C++

inline float int_to_float(uint32_t x) {
  union {
    uint32_t i;
    float f;
  };
  i = x;
  return f;
}

inline uint32_t float_to_int(float x) {
  union {
    uint32_t i;
    float f;
  };
  f = x;
  return i;
}

void print_float(uint32_t x) {
  printf("%f\n",int_to_float(x));
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

uint32_t FEQ(uint32_t x, uint32_t y) {
  return (int_to_float(x) == int_to_float(y));
}

uint32_t FLT(uint32_t x, uint32_t y) {
  return (int_to_float(x) < int_to_float(y));
}

uint32_t FLE(uint32_t x, uint32_t y) {
  return (int_to_float(x) <= int_to_float(y));
}
