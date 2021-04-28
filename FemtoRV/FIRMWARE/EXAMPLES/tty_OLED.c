#include <femtorv32.h>
#include <femtoGL.h>

int main() {
   GL_tty_init(GL_MODE_OLED);
   printf("femtorv32 TTY\n");
   for(;;) {
      int c = getchar();
      if(c != 10 && c !=13) {
	 // putchar(c);
	 printf("char=%d\n", (int)c);
      } else {
	 putchar('\n');
	 putchar(']');
      }
      
   }
   return 0;
}

