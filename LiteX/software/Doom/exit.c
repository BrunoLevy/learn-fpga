#include <stdio.h>

void _exit(int retcode) {
   printf("_exit(%d) called\n",retcode);
   for(;;);
}
