#include <femtorv32.h>

// printf() and support functions have static state
// (initialized RW data segment) we cannot use for 
// now...

int main() {
   GL_tty_init();
   GL_set_bg(0,0,0);
   GL_set_fg(255,255,255);
   GL_clear();
   GL_putchar('H');
   GL_putchar('e');
   GL_putchar('l');
   GL_putchar('l');
   GL_putchar('o');
   for(;;);
}
