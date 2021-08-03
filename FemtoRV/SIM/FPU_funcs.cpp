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

inline int test_bit(uint32_t x, int i) {
  return (x & (1ul << i)) != 0;
}

inline int first_bit_set(uint64_t x) {
  for(int i=63; i>=0; --i) {
    if(test_bit(x, i)) {
      return i;
    }
  }
  return -1;
}

inline int first_bit_set(uint32_t x) {
  for(int i=31; i>=0; --i) {
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

void printb(uint32_t x, int nb_bits=32) {
  for(int i=nb_bits-1; i>=0; --i) {
    printf("%c",test_bit(x,i)?'1':'0');
  }
}

/*********************************************/

class IEEE754 {
public:
  
  IEEE754(uint32_t i_in) : i(i_in) {
  }

  IEEE754(float f_in) : f(f_in) {
  }

  IEEE754(uint32_t mant_in, uint32_t exp_in, uint32_t sign_in) {
    mant = mant_in;
    exp  = exp_in;
    sign = sign_in;
  }

  IEEE754() {
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
    return (exp==0) && (mant==0);
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
      printf("[(%c)-------- ZERO -------------]",sign?'-':'+');
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
  IEEE754 X(x);
  return X.f;
}

inline uint32_t encodef(float x) {
  IEEE754 X(x);
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

uint32_t F_ADD_SUB(uint32_t x, uint32_t y, bool sub) {
  
  IEEE754 X(x), Y(y);
  if(sub) {
    Y.sign = !Y.sign;
  }
  IEEE754 Z(X.f+Y.f);

  if((Y.exp > X.exp) || ((Y.exp == X.exp) && (Y.mant > X.mant))) {
    std::swap(X,Y);
  }
  uint32_t X32 = uint32_t(X.mant | (1 << 23));
  uint32_t Y32 = uint32_t(Y.mant | (1 << 23));
  if(X.exp - Y.exp > 31) {
    Y32 = 0;
  } else {
    Y32 = Y32 >> (X.exp - Y.exp);
  }
  uint32_t sum_mant  = (X32+Y32);
  uint32_t diff_mant = (X32-Y32);
  uint32_t new_mant  = (X.sign ^ Y.sign) ? diff_mant : sum_mant;
  int b = first_bit_set(new_mant);
  if(b > 24) {
    printf("WTF ? b=%d\n",b);
    printf("shift=%d\n", X.exp-Y.exp);
    printf("X="); printb(X32); printf("   "); X.print(); printf("\n");
    printf("Y="); printb(Y32); printf("   "); Y.print(); printf("\n");
  }
  if(b == 24) {
    new_mant = new_mant >> 1; // (b-23); // TODO: rounding
  } else {
    new_mant = new_mant << (23-b);
  }
  int exp = int(X.exp)+b-23;
  int sign = X.sign;
  IEEE754 ZZ(new_mant, exp, sign);
  if(new_mant == 0 || exp<0) {
    ZZ.load_zero();
  } else if(X.is_zero()) {
    ZZ = Y;
  } else if(Y.is_zero()) {
    ZZ = X;
  }
  
  if(
     false && (
     ZZ.sign != Z.sign ||
     ZZ.exp  != Z.exp  ||
     std::abs(ZZ.mant - Z.mant) > 16)
  ) {
    printf("FADD/FSUB ");
    X.print();
    printf(" + ");
    Y.print();
    printf(" = ");
    Z.print();
    printf("\n");
    printf("                                                                                ");
    ZZ.print();
    printf("\n");
  }
  return ZZ.i;
}

uint32_t FADD(uint32_t x, uint32_t y) {
  L("FADD");
  return F_ADD_SUB(x,y,false);
}

uint32_t FSUB(uint32_t x, uint32_t y) {
  L("FSUB");  
  return F_ADD_SUB(x,y,true);
}

uint32_t FMUL(uint32_t x, uint32_t y) {
  L("FMUL");  
  IEEE754 X(x), Y(y);
  IEEE754 Z(X.f*Y.f);
  uint64_t X64 = uint64_t(X.mant | (1 << 23));
  uint64_t Y64 = uint64_t(Y.mant | (1 << 23));  
  uint64_t multiplier = X64*Y64;
  // Normalization: first bit set can only be 47 or 46.
  bool multiplier_47 = test_bit(multiplier,47);
  uint32_t result_mant;
  if(multiplier_47) {
    result_mant = uint32_t(multiplier >> 24);
  } else {
    result_mant = uint32_t(multiplier >> 23);    
  }
  int result_exp = int(X.exp) + int(Y.exp) - (multiplier_47 ? 126 : 127);
  IEEE754 ZZ(result_mant, int(result_exp), X.sign ^ Y.sign);

  // For now commented out (not needed for mandel_float).
  /* if(X.is_NaN() || Y.is_NaN()) {
    ZZ.load_NaN();
  } else if(X.is_infty() || Y.is_infty()) {
    ZZ.load_infty();
  } else */
  
  if(X.is_zero() || Y.is_zero() || result_exp < 0) {
    ZZ.load_zero();
  }
  
  // It *will* bark, because our rounding is a stupid truncation for now...
  /*
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
  IEEE754 X(x), Y(y);
  X.sign = Y.sign;
  return Y.i;
}

uint32_t FSGNJN(uint32_t x, uint32_t y) {
  L("FSGNJN");    
  IEEE754 X(x),Y(y);
  X.sign = !Y.sign;
  return X.i;
}

uint32_t FSGNJX(uint32_t x, uint32_t y) {
  L("FSGNJX");    
  IEEE754 X(x),Y(y);
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
  uint32_t result = (x == y);
  uint32_t check = (decodef(x) == decodef(y));
  if(result != check) {
    IEEE754 X(x);
    IEEE754 Y(y);    
    printf("FEQ ");
    X.print();
    printf(" ==? ");
    Y.print();
    printf(" -> %d %d\n", result, check);
  }
  return result;
}

uint32_t FLT(uint32_t x, uint32_t y) {
  L("FLT");         
  uint32_t check = (decodef(x) < decodef(y));
  IEEE754 X(x), Y(y);
  int s1 = X.sign;
  int s2 = Y.sign;
  X.sign = 0;
  Y.sign = 0;
  uint32_t result = (X.i < Y.i);
  if(s1 && !s2) {
    result = 1;
  } else if(!s1 && s2) {
    result = 0;
  } else if(s1) {
    result = !result;
  } 
  
  if(result != check) {
    printf("FLT ");
    X.print();
    printf(" <? ");
    Y.print();
    printf(" -> %d %d\n", result, check);
  }
  return result;
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
