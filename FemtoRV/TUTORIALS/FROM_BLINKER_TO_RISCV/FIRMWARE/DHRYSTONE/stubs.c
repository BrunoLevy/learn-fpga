#include <stdint.h>
#include <perf.h>

uint64_t time() {
    return rdcycle();
}

uint64_t insn() {
    return rdinstret();
}

char *strcpy(char *dest, const char *src) {
   char* result = dest;
   while(*dest++=*src++);
   return result;
}

int strcmp (const char *p1, const char *p2)  {
   const unsigned char *s1 = (const unsigned char *) p1;
   const unsigned char *s2 = (const unsigned char *) p2;
   unsigned char c1, c2;
   do {
      c1 = (unsigned char) *s1++;
      c2 = (unsigned char) *s2++;
      if (c1 == '\0') {
	 return c1 - c2;
      }
   }
   while (c1 == c2);
   return c1 - c2;
}

/*************************************************************/

// Print "fixed point" number (integer/1000)
void printk(uint64_t kx) {
    int intpart  = (int)(kx / 1000);
    int fracpart = (int)(kx % 1000);
    printf("%d.",intpart);
    if(fracpart<100) {
	printf("0");
    }
    if(fracpart<10) {
	printf("0");
    }
    printf("%d",fracpart);
}

void show_CPI_2() {
   uint64_t instret = rdinstret();
   uint64_t cycles  = rdcycle();
   uint64_t kCPI    = cycles*1000/instret;
   printf(">>> CPI ="); printk(kCPI); printf("\n");
   printf(">>> instret = %d\n", (int)(instret));
   printf(">>> cycles  = %d\n", (int)(cycles));   
}
