#include <femtorv32.h>

char* strncpy(char *dest, const char *src, size_t n) {
   size_t i;
   for (i = 0; i < n && src[i] != '\0'; i++) {
//       printf("1/  i = %d   n=%d\n", i,n);
       dest[i] = src[i];
   }
   for ( ; i < n; i++) {
//       printf("2/  i = %d   n=%d\n", i,n);       
       dest[i] = '\0';
   }
   return dest;
}

