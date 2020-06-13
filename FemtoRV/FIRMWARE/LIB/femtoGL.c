#include <femtorv32.h>

void oled_clear() {
   oled2(0x15,0,127); // column address
   oled2(0x75,0,127); // row address
   oled0(0x5c);       // write RAM
   for(int y=0; y<128; ++y) {
       for(int x=0; x<128; ++x) {
	   IO_OUT(IO_OLED_DATA,0);
	   oled_wait();
	   IO_OUT(IO_OLED_DATA,0);
	   oled_wait();
       }
   }
}

		
