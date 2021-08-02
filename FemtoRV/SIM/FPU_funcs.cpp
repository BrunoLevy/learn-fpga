/*****************************************************************/
#include "FPU_funcs.h"
#include <cstdio>
#include <cmath>
#include <set>
#include <vector>
#include <algorithm>
#include <iostream>

/*********************************************/

#define FPU_LOG

#ifdef FPU_LOG

// Records the calls to FPU functions
// and displays the list on exit.
// To display log from firmware code, 
// send '<ctrl><D>' to UART to exit simulation:
//  UART_putchar(4); 

class FPULogger {
public:
  void log(const char* p) {
    funcs_.insert(std::string(p));
  }
  ~FPULogger() {
    std::vector<std::string> v;
    for(auto i: funcs_) {
      v.push_back(i);
    }
    std::sort(v.begin(), v.end());
     std::cout << std::endl 
               << "FPU funcs called:" 
               << std::endl;
    for(auto i: v) {
      std::cout << i << std::endl;
    }
  }
private:
  std::set<std::string> funcs_;
};

FPULogger logger;
inline void L(const char* s) {
  logger.log(s);
}

#else
#define L(x)
#endif

/*********************************************/

union IEEE754 {
  uint32_t i;  
  float f;
  struct {
    unsigned int mant:23;
    unsigned int exp:8;
    unsigned int sign:1;
  } bits;
};

inline float decodef(uint32_t x) {
  IEEE754 xx;
  xx.i = x;
  return xx.f;
}

inline uint32_t encodef(float x) {
  IEEE754 xx;
  xx.f = x;
  return xx.i;
}

void print_float(uint32_t x) {
  printf("%f\n",decodef(x));
}

/*********************************************/

uint32_t FMADD(uint32_t x, uint32_t y, uint32_t z) {
  L("FMADD");
  return encodef(decodef(x)*decodef(y)+decodef(z));
}

uint32_t FMSUB(uint32_t x, uint32_t y, uint32_t z) {
  L("FMSUB");  
  return encodef(decodef(x)*decodef(y)-decodef(z));  
}

uint32_t FNMADD(uint32_t x, uint32_t y, uint32_t z) {
  L("FNMADD");    
  return encodef(-decodef(x)*decodef(y)-decodef(z));
}

uint32_t FNMSUB(uint32_t x, uint32_t y, uint32_t z) {
  L("FNMSUB");      
  return encodef(-decodef(x)*decodef(y)+decodef(z));  
}

uint32_t FADD(uint32_t x, uint32_t y) {
  L("FADD");
  return encodef(decodef(x)+decodef(y));
}

uint32_t FSUB(uint32_t x, uint32_t y) {
  L("FSUB");  
  return encodef(decodef(x)-decodef(y));
}

uint32_t FMUL(uint32_t x, uint32_t y) {
  L("FMUL");  
  return encodef(decodef(x)*decodef(y));
}

uint32_t FDIV(uint32_t x, uint32_t y) {
  L("FDIV");    
  return encodef(decodef(x)/decodef(y));
}

uint32_t FSQRT(uint32_t x) {
  L("FSQRT");
  return encodef(sqrtf(decodef(x)));
}

uint32_t FSGNJ(uint32_t x, uint32_t y) {
  L("FSGNJ");  
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = yy.bits.sign;
  return xx.i;
}

uint32_t FSGNJN(uint32_t x, uint32_t y) {
  L("FSGNJN");    
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = !yy.bits.sign;
  return xx.i;
}

uint32_t FSGNJX(uint32_t x, uint32_t y) {
  L("FSGNJX");    
  IEEE754 xx,yy;
  xx.i = x; yy.i=y;
  xx.bits.sign = xx.bits.sign ^ yy.bits.sign;
  return xx.i;
}

uint32_t FMIN(uint32_t x, uint32_t y) {
  L("FMIN");    
  return encodef(fminf(decodef(x),decodef(y)));
}

uint32_t FMAX(uint32_t x, uint32_t y) {
  L("FMAX");      
  return encodef(fmaxf(decodef(x),decodef(y)));  
}

uint32_t FCVTWS(uint32_t x) { 
  L("FCVTWS");     
  return uint32_t(int32_t(decodef(x)));  
}

uint32_t FCVTWUS(uint32_t x) {
  L("FCVTWUS");       
  return uint32_t(decodef(x));
}

uint32_t FEQ(uint32_t x, uint32_t y) {
  L("FEQ");         
  return (decodef(x) == decodef(y));
}

uint32_t FLT(uint32_t x, uint32_t y) {
  L("FLT");         
  return (decodef(x) < decodef(y));
}

uint32_t FLE(uint32_t x, uint32_t y) {
  L("FLE");           
  return (decodef(x) <= decodef(y));
}

uint32_t FCLASS(uint32_t x) {
  L("FCLASS");             
  printf("FCLASS - not implemented yet\n");
  return 0;
}

uint32_t FCVTSW(uint32_t x) {
  L("FCVTSW");             
  return encodef(float(int32_t(x)));
}

uint32_t FCVTSWU(uint32_t x) {
  L("FCVTSWU");               
  return encodef(float(x));
}
