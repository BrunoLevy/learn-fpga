#include <femtorv32.h>

char *strcpy(char *dest, const char *src) {
   char* result = dest;
   while(*dest++=*src++);
   return result;
}

