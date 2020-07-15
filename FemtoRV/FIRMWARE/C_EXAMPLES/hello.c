#include <femtorv32.h>

int main() {
   femtosoc_tty_init();

   for(int i=0; i<10; ++i) {
       for(int j=0; j<10; ++j) {
	   printf("%d %d %d %d\n", i, j, i/j, i%j);
       }
   }
   
   /*
   for(;;) {
      printf("Hello, world !!\n");
//    getchar();
   }
   */
   return 0;
}

