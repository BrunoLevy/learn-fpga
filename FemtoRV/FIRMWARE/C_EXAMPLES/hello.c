#include <femtorv32.h>

int main() {
   for(;;) {
      print_string("hello, world\n");
      get_char();
   }
   return 0;
}

