#include <stdlib.h>

extern int femtosoc_tty_init();

int main() {
   //femtosoc_tty_init();
   void* p0 = sbrk(0);
   printf("sbrk=p0=0x%x\n",p0);
   p0 = malloc(0);
   p0 = sbrk(0);
   printf("sbrk=p0=0x%x\n",p0);

   printf("malloc0=p0=0x%x\n",p0);

   void* p1 = malloc(1);
   void* p2 = malloc(0x100);
   void* p3 = malloc(10);
   printf("p1=0x%x\n",p1);
   printf("p2=0x%x\n",p2);
   printf("p3=0x%x\n",p3);

   if (p2 != NULL) free(p2);
   if (p1 != NULL) free(p1);
   void* p4 = malloc(50);
   printf("p4=0x%x\n",p4);
   if (p4 != NULL) free(p4);

   p0 = sbrk(0);
   printf("sbrk=p0=0x%x\n",p0);

   exit(0);
}
