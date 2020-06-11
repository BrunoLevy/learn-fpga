#include <femtorv32.h>

/* print_dec, print_hex taken from picorv32 */

void print_dec(int val) {
   char buffer[255];
   char *p = buffer;
   if(val < 0) {
      put_char('-');
      print_dec(-val);
   }
   while (val || p == buffer) {
      *(p++) = val % 10;
      val = val / 10;
   }
   while (p != buffer) {
      put_char('0' + *(--p));
   }
}

void print_hex(unsigned int val) {
   print_hex_digits(val, 8);
}

/*
static const char* digits = "0123456789ABCDEF";
void print_hex_0(unsigned int val) {
   put_char(digits[(val >> 28) & 15]);
   put_char(digits[(val >> 24) & 15]);
   put_char(digits[(val >> 20) & 15]);
   put_char(digits[(val >> 16) & 15]);
   put_char(digits[(val >> 12) & 15]);
   put_char(digits[(val >> 8) & 15]);
   put_char(digits[(val >> 4) & 15]);
   put_char(digits[val & 15]);
}
*/

void print_hex_digits(unsigned int val, int nbdigits) {
   for (int i = (4*nbdigits)-4; i >= 0; i -= 4) {
      put_char("0123456789ABCDEF"[(val >> i) % 16]);
   }
}

