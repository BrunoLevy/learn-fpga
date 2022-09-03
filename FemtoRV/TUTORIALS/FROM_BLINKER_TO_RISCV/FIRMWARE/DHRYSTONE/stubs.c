#include <perf.h>

long time() {
   return rdcycle();
}

long insn() {
   return rdinstret();
}

int has_counters() {
    return 1; 
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
