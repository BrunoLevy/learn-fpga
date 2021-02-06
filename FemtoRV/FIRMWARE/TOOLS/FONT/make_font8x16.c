#include <stdio.h>
#include "font8x16.xpm"

const int font_width  = 8;
const int font_height = 16;
const int char_per_line = 32;
const int lines = 8;

void printb(int x) {
   for(int b=0; b<16; ++b) {
      printf("%c", (x & (1<<b)) ? '*' : ' ');
   }
}

char digit_to_hex(int x) {
   if(x < 10) {
      return ('0' + x);
   } else {
      return ('a' + (x - 10));
   }
}

char digit_to_HEX(int x) {
   if(x < 10) {
      return ('0' + x);
   } else {
      return ('A' + (x - 10));
   }
}

char* int_to_hex(int x) {
   static char buf[3] = {0,0,0};
   buf[0] = digit_to_hex(x >> 4);
   buf[1] = digit_to_hex(x & 15);
   return buf;
}

void printh(int x) {
  printf("0x");
  printf("%s",int_to_hex((x >> 8)&255));
  printf("%s",int_to_hex(x&255));	 
}

int get_font_column(int c, int column) {
   int result = 0;
   int char_line   = c / char_per_line;
   int char_column = c % char_per_line;
   for(int i=0; i<font_height; ++i) {
      int xpm_line   = 3 + (char_line * font_height) + i;
      int xpm_column = (char_column * font_width) + column;
      if(font8x16_xpm[xpm_line][xpm_column] != ' ') {
	 result = result | (1 << i);
      }
   }
   return result;
}


void gen_chars(int init_lineno, int first) {
   printf("    .word ");
   int word = 0;
   for(int character = first; character < first + 4; ++character) {
      for(int column=0; column<font_width; ++column) {
	 if(!(column&3)) {
	    printf("0x");
	 }
	 printf("%s",int_to_hex(get_font_column(character, column)));
	 if((column&3) == 3 && word!=7) {
	    printf(",");
	    ++word;
	 }
      }
   }
   printf("\n");   
}



int main() {
  printf(
	 ".text\n"
	 ".globl font_8x16\n"
	 "\n"
	 ".section .rodata\n"
	 ".align 4\n"
	 ".LC0:\n"
  );
  for(int c=0; c<255; ++c) {
    printf(".half ");
    for(int col=0; col<font_width; ++col) {
      printh(get_font_column(c,col));
      if(col < font_width-1) {
	printf(", ");
      } else {
	printf("\n");
      }
    }
  }
  printf(
	 "font_8x16:\n"
	 ".word .LC0\n"
  );
}
