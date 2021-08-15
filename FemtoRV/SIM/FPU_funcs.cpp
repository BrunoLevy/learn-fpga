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

int32_t compress(uint32_t mant, int exp, int sign) {
  IEEE754 X(mant, exp, sign);
  return X.i;
}


/*********************************************/

void check(
     const char* func,
     uint32_t rs1, uint32_t rs2, uint32_t rs3,
     uint32_t result,
     uint32_t chk
) {
  IEEE754 RS1(rs1);
  IEEE754 RS2(rs2);
  IEEE754 RS3(rs3);
  IEEE754 RESULT(result);
  IEEE754 CHECK(chk);      
  if(!(RESULT.is_zero() && CHECK.is_zero()) && result != chk) {
    printf("%s mismatch\n",func);
    printf("   RS1="); RS1.print();    printf("\n");
    printf("   RS2="); RS2.print();    printf("\n");
    printf("   RS3="); RS3.print();    printf("\n");
    printf("   Res="); RESULT.print(); printf("\n");
    printf("   Chk="); CHECK.print();  printf("\n");            
  }
}

/*********************************************/

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
    // if(A_mant == 0) A_sign = (A_sign && B_sign);
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


/*********************************************/

uint32_t FMADD(uint32_t x, uint32_t y, uint32_t z) {
  L("FMADD");
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,false,false);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FMADD",x,y,z,result,encodef(fma(decodef(x),decodef(y),decodef(z))));
  return result;
}

uint32_t FMSUB(uint32_t x, uint32_t y, uint32_t z) {
  L("FMSUB");  
  FPU fpu;
  fpu.MUL(x,y);  
  fpu.LOAD_B(z,false,true);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FMSUB",x,y,z,result,encodef(fma(decodef(x),decodef(y),-decodef(z))));
  return result;
}

uint32_t FNMADD(uint32_t x, uint32_t y, uint32_t z) {
  L("FNMADD");
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,true,true);
  if(fpu.ADD_SWP_EXP()) {  
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FNMADD",x,y,z,result,encodef(fma(-decodef(x),decodef(y),-decodef(z))));
  return result;
}

uint32_t FNMSUB(uint32_t x, uint32_t y, uint32_t z) {
  L("FNMSUB");      
  FPU fpu;
  fpu.MUL(x,y);
  fpu.LOAD_B(z,true,false);
  if(fpu.ADD_SWP_EXP()) {  
    fpu.ADD_SHIFT();
    fpu.ADD_SWP_FRAC();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FNMSUB",x,y,z,result,encodef(fma(-decodef(x),decodef(y),decodef(z))));
  return result;
}

uint32_t FADD(uint32_t x, uint32_t y) {
  L("FADD");
  FPU fpu;
  fpu.LOAD_AB(x,y,false);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FADD",x,y,0,result,encodef(decodef(x)+decodef(y)));
  return result;
}

uint32_t FSUB(uint32_t x, uint32_t y) {
  L("FSUB");
  FPU fpu;
  fpu.LOAD_AB(x,y,true);
  if(fpu.ADD_SWP_EXP()) {
    fpu.ADD_SHIFT();
    fpu.ADD_FRAC();
  }
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FSUB",x,y,0,result,encodef(decodef(x)-decodef(y)));
  return result;
}

uint32_t FMUL(uint32_t x, uint32_t y) {
  L("FMUL");
  FPU fpu;
  fpu.MUL(x,y);
  fpu.NORM();
  uint32_t result = fpu.result();
  check("FMUL",x,y,0,result,encodef(decodef(x)*decodef(y)));    
  return result;
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
