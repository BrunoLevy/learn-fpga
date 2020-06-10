/*
 * Generates a sinus table.
 * Do not try compiling this one on the femtoRV !
 */

#include <math.h>
#include <stdio.h>

void main() {
   const int NB = 64;
   const int factor = 256;
   printf("int sintab[%d] = {",NB);
   for(int i=0; i<NB; ++i) {
      double alpha = 2.0*M_PI*(double)i/(double)NB;
      printf("%d",(int)(factor*sin(alpha)));
      if(i != NB-1) {
	 printf(",");
      }
   }
   printf("};\n");
}
