// Testing the OLED screen, displaying an animated pattern with
// all the 65K colors.

#include <femtorv32.h>

int main() {
    GL_init();
    GL_clear();
    int frame = 0;
    for(;;) {
        oled_write_window(0,0,127,127);
	for(uint32_t y=0; y<128; ++y) {
	    for(uint32_t x=0; x<128; ++x) {
		uint32_t R = (x+frame) & 63;
		uint32_t G = (x >> 3)  & 63;
		uint32_t B = (y+frame) & 63;
		// pixel color: RRRRR GGGGG 0 BBBBB
		IO_OUT(IO_SSD1351_DAT,(G>>2)|(R<<3));
		IO_OUT(IO_SSD1351_DAT,B|(G << 6));
	    }
	}
	++frame;
    }
    return 0;
}
