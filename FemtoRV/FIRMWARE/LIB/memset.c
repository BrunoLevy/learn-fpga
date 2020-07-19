#include <femtorv32.h>

/*
 * Super-slow memset function.
 * TODO: write word by word.
 */ 
void* memset(void* s, int c, size_t n) {
   uint8_t* p = (uint8_t*)s;
   for(size_t i=0; i<n; ++i) {
       asm("nop"); // Needed, because I think I've got a processor bug !!
       *p = (uint8_t)c;
       p++;
   }
}

