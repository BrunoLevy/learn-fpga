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

inline int test_bit(uint64_t x, int i) {
  return (x & (1ull << i)) != 0;
}

inline int first_bit_set(uint64_t x) {
  for(int i=63; i>=0; --i) {
    if(test_bit(x, i)) {
      return i;
    }
  }
  return -1;
}

void printb(uint64_t x, int nb_bits=64) {
  for(int i=nb_bits-1; i>=0; --i) {
    printf("%c",test_bit(x,i)?'1':'0');
  }
}

/*********************************************/

class IEEE764 {
public:
  
  IEEE764(uint32_t i_in) : i(i_in) {
  }

  IEEE764(float f_in) : f(f_in) {
  }

  IEEE764(uint32_t mant_in, uint32_t exp_in, uint32_t sign_in) {
    mant = mant_in;
    exp  = exp_in;
    sign = sign_in;
  }

  IEEE764() {
    load_zero();
  }

  void load_zero() {
    i = 0;
  }

  void load_NaN() {
    exp  = 255;    
    mant = 1;
    sign = 0;
  }

  void load_infty() {
    exp = 255;
    mant = 0;
  }

  bool is_zero() const {
    return i == 0;
  }

  bool is_denormal() const {
    return !is_zero() && exp == 0;
  }

  bool is_normal() const {
    return exp != 0 && exp != 255;
  }

  bool is_infty() const {
    return exp == 255 && mant == 0;
  }

  bool is_NaN() const {
    return exp == 255 && mant != 0;
  }
  
  void print() {
    if(is_zero()) {
      printf("[----------- ZERO -------------]");
      return;
    }
    printf("%c",sign ? '-' : '+');
    printf("1");
    printb(mant,23);
    printf("E[%4d]",int(exp)-127);
    fflush(stdout);
  }
  
  union {
    uint32_t i;  
    float f;
    struct {
      unsigned int mant:23;
      unsigned int exp:8;
      unsigned int sign:1;
    };
  };
};

inline float decodef(uint32_t x) {
  IEEE764 X(x);
  return X.f;
}

inline uint32_t encodef(float x) {
  IEEE764 X(x);
  return X.i;
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
  IEEE764 X(x), Y(y);
  IEEE764 Z(X.f*Y.f);
  // return Z.i;

  // Let's try to implement IEEE754 multiplication in C++
  // (then we'll redo that in VERILOG !!!)
  
  uint64_t X64 = uint64_t(X.mant | (1 << 23));
  uint64_t Y64 = uint64_t(Y.mant | (1 << 23));  
  uint64_t prod_mant = (X64*Y64);
  int b = first_bit_set(prod_mant);
  prod_mant = prod_mant >> (b-23); // TODO: rounding
  int exp = int(X.exp) + int(Y.exp) + b - 127 - 46;
      // 127: do not apply bias twice (both exponents are biased)
      //  46: both factors are 2^23 larger than what the exponent says
  
  if(exp < 0)   { exp = 0; } // Underflow
  if(exp > 255) { exp = 255; prod_mant = 0; } // Overflow -> infy
  
  IEEE764 ZZ(uint32_t(prod_mant), exp, X.sign^Y.sign);
  if(X.is_NaN() || Y.is_NaN()) {
    ZZ.load_NaN();
  } else if(X.is_infty() || Y.is_infty()) {
    ZZ.load_infty();
  } else if(exp < 0 || X.is_zero() || Y.is_zero()) {
    ZZ.load_zero();
  }

  /* 
  // It *will* bark, because our rounding is a stupid truncation.
  if(ZZ.i != Z.i) {
    printf("FMUL ");
    X.print();
    printf(" * ");
    Y.print();
    printf(" = ");
    Z.print();
    printf("\n");
    printf("                                                                           ");
    ZZ.print();
    printf("\n");
  }
  */
  
  return ZZ.i;
  
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
  IEEE764 X(x), Y(y);
  X.sign = Y.sign;
  return Y.i;
}

uint32_t FSGNJN(uint32_t x, uint32_t y) {
  L("FSGNJN");    
  IEEE764 X(x),Y(y);
  X.sign = !Y.sign;
  return X.i;
}

uint32_t FSGNJX(uint32_t x, uint32_t y) {
  L("FSGNJX");    
  IEEE764 X(x),Y(y);
  X.sign = X.sign ^ Y.sign;
  return X.i;
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
