/*****************************************************************/
#include "FPU_funcs.h"
#include <cstdio>
#include <cmath>
#include <set>
#include <vector>
#include <algorithm>
#include <iostream>
#include <cstring>
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

// Count leading zeroes
inline int clz(uint32_t x) {
  int result = 0;
  for(int i=31; i>=0; --i) {
    if(test_bit(x,i)) {
      return result;
    }
    ++result;
  }
  return result;
}

// Count leading zeroes
inline int clz(uint64_t x) {
  int result = 0;
  for(int i=63; i>=0; --i) {
    if(test_bit(x,i)) {
      return result;
    }
    ++result;    
  }
  return result;
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

void print_spaces(int nb) {
  for(int i=0; i<nb; ++i) {
    printf(" ");
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
    if(is_NaN()) {
      printf("[----------- NaN -------------]");
      return;
    }
    if(is_infty()) {
      printf("[(%c)-------- INFTY ------------]",sign?'-':'+');
      return;
    }
    printf("%c",sign ? '-' : '+');
    printf("%c",is_denormal() ? '0' : '1');
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

void expand(uint32_t x, uint64_t& mant, int& exp, int& sign) {
  IEEE754 X(x);
  exp = X.exp;
  mant = uint64_t(X.mant);
  sign = X.sign;
  if(exp != 0) { mant |= uint64_t(1) << 23; }
}

void expand(uint32_t x, uint32_t& mant, int& exp, int& sign) {
  IEEE754 X(x);
  exp = X.exp;
  mant = X.mant;
  sign = X.sign;
  if(exp != 0) { mant |= uint64_t(1) << 23; }
}

int32_t compress(uint32_t mant, int exp, int sign) {
  IEEE754 X(mant, exp, sign);
  return X.i;
}


/*********************************************/

uint32_t check(
     const char* func,
     uint32_t rs1, uint32_t rs2, uint32_t rs3,
     uint32_t result,
     uint32_t chk,
     int nb_args = 3,
     bool int_result = false,
     bool int_arg    = false
) {
  IEEE754 RS1(rs1);
  IEEE754 RS2(rs2);
  IEEE754 RS3(rs3);
  IEEE754 RESULT(result);
  IEEE754 CHECK(chk);

  // printf("CHECK%s\n",func);
  
  if(!(RESULT.is_zero() && CHECK.is_zero()) && result != chk) {
    printf("%s mismatch\n",func);

    if(int_arg) {
      printf("   RS1="); printb(rs1); printf("   (%d)\n",rs1);
    } else {
      printf("   RS1="); RS1.print(); printf("   (%f)\n",RS1.f);      
    }

    
    if(nb_args >= 2) { printf("   RS2="); RS2.print(); printf("   (%f)\n",RS2.f); }
    if(nb_args >= 3) { printf("   RS3="); RS3.print(); printf("   (%f)\n",RS3.f); }
    if(int_result) {
      printf("   Res="); printb(result); printf("   (%d)\n",result);
      printf("   Chk="); printb(chk);    printf("   (%d)\n",chk);
    } else {
      printf("   Res="); RESULT.print(); printf("   (%f)\n",RESULT.f);
      printf("   Chk="); CHECK.print();  printf("   (%f)\n",CHECK.f);
    }
    return 0;
  } else {
    //    printf("%s OK\n",func);
  }
  return 1;
}

/*********************************************/

// C++ code to test the algorithms before implementing femtorv32-petitbateau
// completely in VERILOG.
class FPU {
public:
  int32_t result() const {
    return compress(uint32_t(A_mant), A_exp, A_sign);
  }

  // A <- rs1 * rs2
  // (does not normalize)
  void MUL(uint32_t rs1, uint32_t rs2) {
    uint64_t rs1_mant;
    int      rs1_exp; 
    int      rs1_sign;
    expand(rs1, rs1_mant, rs1_exp, rs1_sign);

    uint64_t rs2_mant;
    int      rs2_exp; 
    int      rs2_sign;
    expand(rs2, rs2_mant, rs2_exp, rs2_sign);
    
    A_mant = rs1_mant*rs2_mant;
    A_exp  = rs1_exp+rs2_exp-127-23;
    A_sign = rs1_sign ^ rs2_sign;
  }

  // A <- rs1 * rs2
  // B <- rs3
  // (does not normalize)
  void LOAD_B(uint32_t rs3, bool ch_A_sign, bool ch_B_sign) {
    expand(rs3, B_mant, B_exp, B_sign);
    B_mant = B_mant << 24;
    B_exp -= 24;
    if(ch_A_sign) {
      A_sign = !A_sign;
    }
    if(ch_B_sign) {
      B_sign = !B_sign;
    }
  }
  
  // Normalize A 
  void NORM() {
    normalize23(A_mant, A_exp);
  }

  // A <= rs1; B <=  rs2 (if !sub)
  // A <= rs1; B <= -rs2 (if  sub)
  void LOAD_AB(uint32_t rs1, uint32_t rs2, bool sub) {
    expand(rs1, A_mant, A_exp, A_sign);
    expand(rs2, B_mant, B_exp, B_sign);
    A_mant = A_mant << 24;
    A_exp -= 24;
    B_mant = B_mant << 24;
    B_exp -= 24;
    if(sub) { B_sign = !B_sign; }
  }

  // Set largest magnitude in B. 
  // returns false if one of A,B is zero, then the other one is in A
  bool ADD_SWP_EXP() {
    
    if(B_mant == 0) {
      return false;
    }
    
    if(A_mant == 0) {
      std::swap(A_mant,B_mant); 
      std::swap(A_exp, B_exp);
      std::swap(A_sign,B_sign);
      return false;
    }
    
    if(A_exp > B_exp || (A_exp == B_exp) && (A_mant > B_mant)) {
      std::swap(A_mant,B_mant);  
      std::swap(A_exp, B_exp);
      std::swap(A_sign,B_sign);
    }
    
    return true;
  }

  // Normalize operands magnitude by shifting A
  void ADD_SHIFT() {
    if(B_exp - A_exp > 47) {
      A_mant=0;
      A_exp = B_exp;
    } else {
      A_mant = A_mant >> (B_exp - A_exp);
      A_exp  = B_exp;
    }
    A_exp = B_exp;
  }

  // A <= A+B
  void ADD_FRAC() {
    // With FMADD:
    //    - Once they are shifted, the order between A and B may change.
    //    - Can it happen with FADD/FSUB ? 
    A_mant = (A_sign ^ B_sign) ? B_mant - A_mant : B_mant + A_mant;
    A_sign = (A_mant == 0) ? A_sign && B_sign : B_sign;
  }
  

  // Largest magnitude in B, after shifting
  //  - Once they are shifted, the order between A and B may change.
  //  - This does not seem to happen with FADD/FSUB (is it true ?)
  void ADD_SWP_FRAC() {
    if(A_mant > B_mant) {
      std::swap(A_mant,B_mant);
      std::swap(A_exp, B_exp);
      std::swap(A_sign,B_sign);  
    }
  }

  void log(const char* step) {
    printf("%s A %c",step, A_sign ? '+' : '-'); printb(A_mant); printf(" E[%d]\n",A_exp-127);
    printf("%s B %c",step, B_sign ? '+' : '-'); printb(B_mant); printf(" E[%d]\n",B_exp-127);    
  }


void normalize23(uint64_t& mant, int& exp) {

  if(exp < -255 || exp > 255) {
    printf("EXP OVERFLOW !!\n");
  }
  
  int first_bit_set = 63-clz(mant);
  if(first_bit_set == -1) {
    exp = 0;
  } else {
    
    // Note: possible optimization for MUL
    // without denormals and MUL,
    // first_bit_set = 46 or 47, always

    if(exp+first_bit_set-23 > 0) {
      exp += (first_bit_set-23);    
      if(first_bit_set > 23) {
	mant = mant >> (first_bit_set-23);
      } else {
	// Happens sometimes with MADD. TODO: Can it happen with ADD ?
	mant = mant << (23-first_bit_set);
      }
    } else {
      // Flush all denormals to zero (for now)
      // See sim_main.cpp
      mant = 0;
      exp  = 0;
      
      // TODO: handle denormals properly
      //   (mismatch triggered by tinyraytracer)
      // log("DENORM1");
      // mant = mant >> (128-exp); // 128-exp or 129-exp I don't know
      // exp  = 0;      
      // log("DENORM2");      
      // mant = 0;
    }
  }

}
  
private:
  // Accumulator and shifter
  uint64_t A_mant;
  int      A_exp;
  int      A_sign;

  // Operand
  uint64_t B_mant;
  int      B_exp;
  int      B_sign;
};


/********************************************************************************/

uint32_t FMADD_WITH_SOFT_FPU(uint32_t x, uint32_t y, uint32_t z) {
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,false,false);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FMSUB_WITH_SOFT_FPU(uint32_t x, uint32_t y, uint32_t z) {
  FPU fpu;
  fpu.MUL(x,y);  
  fpu.LOAD_B(z,false,true);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FNMADD_WITH_SOFT_FPU(uint32_t x, uint32_t y, uint32_t z) {
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,true,true);
  if(fpu.ADD_SWP_EXP()) {  
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FNMSUB_WITH_SOFT_FPU(uint32_t x, uint32_t y, uint32_t z) {
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,true,false);
  if(fpu.ADD_SWP_EXP()) {  
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FADD_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  FPU fpu;
  fpu.LOAD_AB(x,y,false);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FSUB_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  FPU fpu;
  fpu.LOAD_AB(x,y,true);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  return fpu.result();
}

uint32_t FMUL_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  FPU fpu;
  fpu.MUL(x,y);
  fpu.NORM();
  return fpu.result();
}

// Stack Overflow - Fast 1/X division (reciprocal)
float DOOM_approx_inv_sqrt(float x) {
  float x2 = x * 0.5f;
  uint32_t i = 0x5f3759df - (encodef(x) >> 1);
  float y = decodef(i);
  y = y * (1.5f - (x2 * y * y));
  y = y * (1.5f - (x2 * y * y)); // two iterations are needed for tinyraytracer
  return y;
}

// reciprocal (1/x)
uint32_t FRCP_WITH_SOFT_FPU(uint32_t D_in) {

  // version 0: use simulator's FPU
  if(0) {
    return encodef(1.0/decodef(D_in));
  }

  // version 1: Newton-Raphson implemented with floats
  if(0) {
    float D = decodef(D_in);
    float D_prime = fabs(D);
    int D_shift = 0;
    
    float N_prime = 1.0f;
  
    while(D_prime < 0.5f) {
      D_prime *= 2.0f;
      N_prime *= 2.0f;
    }
  
    while(D_prime > 1.0f) {
      D_prime /= 2.0f;
      N_prime /= 2.0f;    
    }

    if(D < 0) {
      N_prime = -N_prime;
    }
    
    float X0 = 48.0f/17.0f - 32.0f/17.0f * D_prime;
    float X1 = X0 + X0 * (1.0f - D_prime * X0);
    float X2 = X1 + X1 * (1.0f - D_prime * X1);

    return encodef(N_prime*X2);
  }

  // version 2: Newton-Raphson implemented with integers
  // https://en.wikipedia.org/wiki/Division_algorithm#Newton%E2%80%93Raphson_division
  if(1) {
    uint32_t D_frac;
    int D_exp;
    int D_sign;
    expand(D_in, D_frac, D_exp, D_sign);

    uint32_t D_prime_ = compress(D_frac, 126, 0);
    
    const uint32_t CONST_48_over_17 = 0x4034B4B5;
    const uint32_t CONST_32_over_17 = 0x3FF0F0F1;
    const uint32_t CONST_2          = 0x40000000;
    const uint32_t CONST_1          = 0x3f800000;
    
    uint32_t X0_ = FNMSUB(CONST_32_over_17,D_prime_,CONST_48_over_17);
    
    // version 1 of iteration, like in Wikipedia page
    // uint32_t X1_ = FMADD(X0_,FNMSUB(D_prime_,X0_,CONST_1),X0_);
    // uint32_t X2_ = FMADD(X1_,FNMSUB(D_prime_,X1_,CONST_1),X1_);
    // uint32_t X3_ = FMADD(X2_,FNMSUB(D_prime_,X2_,CONST_1),X2_);    

    // version 2 of iteration, using one FMA and one MUL per iteration
    // (faster, but probably not as accurate, to be checked)
    uint32_t X1_ = FMUL(X0_, FNMSUB(X0_,D_prime_,CONST_2));
    uint32_t X2_ = FMUL(X1_, FNMSUB(X1_,D_prime_,CONST_2));
    // uint32_t X3_ = FMUL(X2_, FNMSUB(D_prime_,X2_,CONST_2));
    // Note: does not pass compliance test yet, and two iters
    // may not suffice (but not the only reason)
    // TODO: study rounding modes.

    
    uint32_t X_frac;
    int X_exp;
    int X_sign;
    expand(X2_, X_frac, X_exp, X_sign);
    uint32_t result = compress(X_frac, 126-D_exp+X_exp, D_sign);
      
    return result;
  }
}

uint32_t FDIV_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  return FMUL_WITH_SOFT_FPU(x, FRCP_WITH_SOFT_FPU(y));
}

uint32_t FSQRT_WITH_SOFT_FPU(uint32_t x) {
  return FMUL_WITH_SOFT_FPU(x,encodef(DOOM_approx_inv_sqrt(decodef(x))));
}

uint32_t FSGNJ_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  IEEE754 X(x), Y(y);
  X.sign = Y.sign;
  return Y.i;
}

uint32_t FSGNJN_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  IEEE754 X(x),Y(y);
  X.sign = !Y.sign;
  return X.i;
}

uint32_t FSGNJX_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  IEEE754 X(x),Y(y);
  X.sign = X.sign ^ Y.sign;
  return X.i;
}

uint32_t FMIN_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  return encodef(fminf(decodef(x),decodef(y)));
}

uint32_t FMAX_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  return encodef(fmaxf(decodef(x),decodef(y)));  
}

uint32_t FCVTWS_WITH_SOFT_FPU(uint32_t x) { 
  L("FCVTWS");
  // TODO: overflow detect
  uint32_t result;
  IEEE754 X(x);
  if(X.exp == 0) {
    result = 0;
  } else {
    result = X.mant | (1 << 23);
    int shift = int(X.exp) - (127 + 23);
    if(shift > 0) {
      result = result << shift;
    } else {
      result = result >> -shift;
    }
  }
  if(X.sign) {
    result = uint32_t(-int32_t(result));
  }
  return result;
}

uint32_t FCVTWUS_WITH_SOFT_FPU(uint32_t x) {
  // TODO: overflow detect
  L("FCVTWUS");
  uint32_t result;
  IEEE754 X(x);
  if(X.exp == 0) {
    result = 0;
  } else {
    result = X.mant | (1 << 23);
    int shift = int(X.exp) - (127 + 23);
    if(shift > 0) {
      result = result << shift;
    } else {
      result = result >> -shift;
    }
  }
  return result;
}

uint32_t FEQ_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  uint32_t result = (x == y);
  // TODO: +zero/-zero
  return result;
}

uint32_t FLT_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
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
  return result;
}

uint32_t FLE_WITH_SOFT_FPU(uint32_t x, uint32_t y) {
  return (decodef(x) <= decodef(y));
}

uint32_t FCLASS_WITH_SOFT_FPU(uint32_t x) {
  printf("FCLASS - not implemented yet\n");
  return 0;
}

uint32_t FCVTSW_WITH_SOFT_FPU(uint32_t x) {
  return encodef(float(int32_t(x)));
}

uint32_t FCVTSWU_WITH_SOFT_FPU(uint32_t x) {
  return encodef(float(x));
}

/*****************************************************************************/

static int use_soft_fpu = 0;

uint32_t FMADD(uint32_t x, uint32_t y, uint32_t z) {
  if(use_soft_fpu) {
    return FMADD_WITH_SOFT_FPU(x,y,z);
  }
  L("FMADD");
  return encodef(fma(decodef(x),decodef(y),decodef(z)));
}

uint32_t FMSUB(uint32_t x, uint32_t y, uint32_t z) {
  if(use_soft_fpu) {
    return FMSUB_WITH_SOFT_FPU(x,y,z);
  }
  L("FMSUB");
  return encodef(fma(decodef(x),decodef(y),-decodef(z)));
}

uint32_t FNMADD(uint32_t x, uint32_t y, uint32_t z) {
  if(use_soft_fpu) {
    return FNMADD_WITH_SOFT_FPU(x,y,z);
  }
  L("FNMADD");
  return encodef(fma(-decodef(x),decodef(y),-decodef(z)));
}

uint32_t FNMSUB(uint32_t x, uint32_t y, uint32_t z) {
  if(use_soft_fpu) {
    return FNMSUB_WITH_SOFT_FPU(x,y,z);
  }
  L("FNMSUB");
  return encodef(fma(-decodef(x),decodef(y),decodef(z)));
}

uint32_t FADD(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FADD_WITH_SOFT_FPU(x,y);
  }
  L("FADD");
  return encodef(decodef(x)+decodef(y));
}

uint32_t FSUB(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FSUB_WITH_SOFT_FPU(x,y);
  }
  L("FSUB");
  return encodef(decodef(x)-decodef(y));  
}

uint32_t FMUL(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FMUL_WITH_SOFT_FPU(x,y);
  }
  L("FMUL");
  return encodef(decodef(x)*decodef(y));    
}

uint32_t FDIV(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FDIV_WITH_SOFT_FPU(x,y);
  }
  L("FDIV");    
  return encodef(decodef(x)/decodef(y));
}

uint32_t FSQRT(uint32_t x) {
  if(use_soft_fpu) {
    return FSQRT_WITH_SOFT_FPU(x);
  }
  L("FSQRT");
  return encodef(sqrtf(decodef(x)));
}

uint32_t FSGNJ(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FSGNJ_WITH_SOFT_FPU(x,y);
  }
  L("FSGNJ");  
  IEEE754 X(x), Y(y);
  X.sign = Y.sign;
  return Y.i;
}

uint32_t FSGNJN(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FSGNJN_WITH_SOFT_FPU(x,y);
  }
  L("FSGNJN");    
  IEEE754 X(x),Y(y);
  X.sign = !Y.sign;
  return X.i;
}

uint32_t FSGNJX(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FSGNJX_WITH_SOFT_FPU(x,y);
  }
  L("FSGNJX");    
  IEEE754 X(x),Y(y);
  X.sign = X.sign ^ Y.sign;
  return X.i;
}

uint32_t FMIN(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FMIN_WITH_SOFT_FPU(x,y);
  }
  L("FMIN");    
  return encodef(fminf(decodef(x),decodef(y)));
}

uint32_t FMAX(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FMAX_WITH_SOFT_FPU(x,y);
  }
  L("FMAX");      
  return encodef(fmaxf(decodef(x),decodef(y)));  
}

uint32_t FCVTWS(uint32_t x) {
  if(use_soft_fpu) {
    return FCVTWS_WITH_SOFT_FPU(x);
  }
  L("FCVTWS");
  return uint32_t(int32_t(decodef(x)));
}

uint32_t FCVTWUS(uint32_t x) {
  if(use_soft_fpu) {
    return FCVTWUS_WITH_SOFT_FPU(x);
  }
  L("FCVTWUS");
  return uint32_t(decodef(x));
}

uint32_t FEQ(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FEQ_WITH_SOFT_FPU(x,y);
  }
  L("FEQ");
  return uint32_t(decodef(x) == decodef(y));
}

uint32_t FLT(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FLT_WITH_SOFT_FPU(x,y);
  }
  L("FLT");
  return uint32_t(decodef(x) < decodef(y));
}

uint32_t FLE(uint32_t x, uint32_t y) {
  if(use_soft_fpu) {
    return FLE_WITH_SOFT_FPU(x,y);
  }
  L("FLE");           
  return uint32_t(decodef(x) <= decodef(y));
}

uint32_t FCLASS(uint32_t x) {
  if(use_soft_fpu) {
    return FCLASS_WITH_SOFT_FPU(x);
  }
  L("FCLASS");             
  printf("FCLASS - not implemented yet\n");
  return 0;
}

uint32_t FCVTSW(uint32_t x) {
  if(use_soft_fpu) {
    return FCVTSW_WITH_SOFT_FPU(x);
  }
  L("FCVTSW");             
  return encodef(float(int32_t(x)));
}

uint32_t FCVTSWU(uint32_t x) {
  if(use_soft_fpu) {
    return FCVTSWU_WITH_SOFT_FPU(x);
  }
  L("FCVTSWU");               
  return encodef(float(x));
}

/***********************************************************/

uint32_t CHECK_FADD(uint32_t result, uint32_t x, uint32_t y) { 
  return check("FADD", x, y, 0, result, encodef(decodef(x) + decodef(y)),2);
}

uint32_t CHECK_FSUB(uint32_t result, uint32_t x, uint32_t y) {
  return check("FSUB", x, y, 0, result, encodef(decodef(x) - decodef(y)),2);  
}

uint32_t CHECK_FMUL(uint32_t result, uint32_t x, uint32_t y) {
  return check("FMUL", x, y, 0, result, encodef(decodef(x) * decodef(y)),2);  
}

uint32_t CHECK_FMADD(uint32_t result, uint32_t x, uint32_t y, uint32_t z) {
  return check("FMADD", x, y, 0, result, encodef(fma(decodef(x),decodef(y),decodef(z))),3);  
}

uint32_t CHECK_FMSUB(uint32_t result, uint32_t x, uint32_t y, uint32_t z) {
  return check("FMSUB", x, y, 0, result, encodef(fma(decodef(x),decodef(y),-decodef(z))),3);  
}

uint32_t CHECK_FNMADD(uint32_t result, uint32_t x, uint32_t y, uint32_t z) {
  return check("FNMADD", x, y, 0, result, encodef(fma(-decodef(x),decodef(y),-decodef(z))),3);    
}

uint32_t CHECK_FNMSUB(uint32_t result, uint32_t x, uint32_t y, uint32_t z) {
  return check("FNMSUB", x, y, 0, result, encodef(fma(-decodef(x),decodef(y),decodef(z))),3);      
}

uint32_t CHECK_FEQ(uint32_t result, uint32_t x, uint32_t y) {
  return check("FEQ", x, y, 0, result,(decodef(x)==decodef(y)),2,true);    
}

uint32_t CHECK_FLT(uint32_t result, uint32_t x, uint32_t y) {
  return check("FLT", x, y, 0, result,(decodef(x)<decodef(y)),2,true);      
}

uint32_t CHECK_FLE(uint32_t result, uint32_t x, uint32_t y) {
  return check("FLE", x, y, 0, result,(decodef(x)<=decodef(y)),2,true);        
}

uint32_t CHECK_FCVTWS(uint32_t result, uint32_t x) {
  return check("FCVT.W.S", x, 0, 0, result, uint32_t(int32_t(decodef(x))),1,true);
}

uint32_t CHECK_FCVTWUS(uint32_t result, uint32_t x) {
  return check("FCVT.WU.S", x, 0, 0, result, int32_t(decodef(x)),1,true);
}

uint32_t CHECK_FCVTSW(uint32_t result, uint32_t x) {
  return check("FCVT.S.W", x, 0, 0, result, encodef(float(int32_t(x))),1,false,true);  
}

uint32_t CHECK_FCVTSWU(uint32_t result, uint32_t x) {
  return check("FCVT.S.W", x, 0, 0, result, encodef(float(x)),1,false,true);  
}

uint32_t CHECK_FDIV(uint32_t result, uint32_t x, uint32_t y) {
  return check("FDIV", x, y, 0, result, encodef(decodef(x) / decodef(y)),2);  
}

uint32_t CHECK_FSQRT(uint32_t result, uint32_t x) {
  return check("FSQRT", x, 0, 0, result, encodef(sqrtf(decodef(x))),1);  
}

uint32_t CHECK_FMIN(uint32_t result, uint32_t x, uint32_t y) {
  return check("FMIN", x, y, 0, result, encodef(fminf(decodef(x),decodef(y))),2);    
}

uint32_t CHECK_FMAX(uint32_t result, uint32_t x, uint32_t y) {
  return check("FMAX", x, y, 0, result, encodef(fmaxf(decodef(x),decodef(y))),2);      
}

uint32_t CHECK_FSGNJ(uint32_t result, uint32_t x, uint32_t y) { return 1; }
uint32_t CHECK_FSGNJN(uint32_t result, uint32_t x, uint32_t y) { return 1; }
uint32_t CHECK_FSGNJX(uint32_t result, uint32_t x, uint32_t y) { return 1; }
uint32_t CHECK_FCLASS(uint32_t result, uint32_t x) { return 1; }
