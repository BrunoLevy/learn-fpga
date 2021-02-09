#include <stdlib.h>

extern int femtosoc_tty_init();

int main() {
   femtosoc_tty_init();
   void* p1 = malloc(10);
   void* p2 = malloc(100);
   printf("p1=0x%x\n",p1);
   printf("p2=0x%x\n",p2);
   free(p2);
   free(p1);
   void* p3 = malloc(50);
   printf("p1=0x%x\n",p3);   
   exit(0);
}
