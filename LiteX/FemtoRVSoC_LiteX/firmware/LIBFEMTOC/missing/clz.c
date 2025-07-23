#include "../femtostdlib.h"

// Number of leading zero bits
// (I do not know where the source of this function is, did not find
//  it in riscv-glibc)
int __clzsi2(unsigned int x) {
   unsigned int mask = (1 << 31);
   for(int i=0; i<32; ++i) {
      if(x & mask) {
	 return i;
      }
      mask = mask >> 1;
   }
   return 32;
}
