#include <femtorv32.h>

/*
void my_print_hex_digits(unsigned int val, int nbdigits) {
   for (int i = (4*nbdigits)-4; i >= 0; i -= 4) {
      put_char("0123456789ABCDEF"[(val >> i) % 16]);
   }
}
*/

void main() {
   for(;;) {
      print_string("hello, world\n");
      get_char();
/*      
      for(int i=0; i<100; ++i) {
	 print_dec(i);
	 print_string("   ");
	 my_print_hex_digits(i,8);
	 print_string("\n");
      }
*/ 
   }
}

