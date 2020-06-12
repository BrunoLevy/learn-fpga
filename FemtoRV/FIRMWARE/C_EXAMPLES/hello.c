#include <femtorv32.h>

void main() {
   for(;;) {
      print_string("hello, world\n");
      get_char();
   }
}

