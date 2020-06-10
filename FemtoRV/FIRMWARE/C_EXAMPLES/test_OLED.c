// Testing the OLED screen, displaying an animated pattern with
// all the 65K colors.

#include <femtorv32.h>

void main() {
    oled_init();
    int frame = 0;
    for(;;) {
	oled2(0x15,0x00,0x7f); // column address
	oled2(0x75,0x00,0x7f); // row address
	oled0(0x5c);           // write RAM
	for(uint32 y=0; y<128; ++y) {
	    for(uint32 x=0; x<128; ++x) {
		uint32 R = (x+frame)&63;
		uint32 G = (x >> 3);
		uint32 B = y+frame;
		// pixel color: RRRRR GGGGG 0 BBBBB
		IO_OUT(IO_OLED_DATA,(G>>2)|(R<<3));
	        oled_wait();
		IO_OUT(IO_OLED_DATA,B|(G << 6));
	        oled_wait();
	    }
	}
	++frame;
    }
}
