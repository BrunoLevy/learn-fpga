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
                // TODO OLED_WRITE_DATA_UINT8_UINT8((G>>2)|(R<<3),B|(G << 6));

		OLED_WRITE_DATA_UINT16(B | (G << 6) | (R << 11));
		
	    }
	}
	++frame;
    }
    return 0;
}
