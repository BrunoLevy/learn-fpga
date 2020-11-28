#include <femtorv32.h>

int main() {
   GL_tty_init();
   printf("femtorv32 TTY\n");
   for(;;) {
      int c = getchar();
      if(c != 10 && c !=13) {
	 putchar(c);
      } else {
	 putchar('\n');
	 putchar(']');
      }
      
   }
   return 0;
}

