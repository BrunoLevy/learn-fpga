/* taken from Claire Wolf's picorv32 libraries */
#include <stddef.h>
#include <stdio.h>

void *sbrk(ptrdiff_t incr);
void *sbrk(ptrdiff_t incr) {
   
           extern unsigned char _end[];   // Defined by linker
           static unsigned long heap_end = 0;
   
//         printf("SBRK %d\n",(int)incr);
   
           if (heap_end == 0)
                     heap_end = (long)_end;
   
           heap_end += incr;
           return (void *)(heap_end - incr);
}

