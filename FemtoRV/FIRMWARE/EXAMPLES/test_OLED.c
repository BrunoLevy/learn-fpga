// Testing the OLED screen, displaying an animated pattern with
// all the 65K colors.

#include <femtorv32.h>

#define WIDTH  OLED_WIDTH
#define HEIGHT OLED_HEIGHT

int main() {
    GL_init();
    GL_clear();
    int frame = 0;
    for(;;) {
        oled_write_window(0,0,WIDTH-1,HEIGHT-1);
	for(uint32_t y=0; y<HEIGHT; ++y) {
	    for(uint32_t x=0; x<WIDTH; ++x) {
		uint32_t R = (x+frame) & 63;
		uint32_t G = (x >> 3)  & 63;
		uint32_t B = (y+frame) & 63;
	        // pixel color: RRRRR GGGGG 0 BBBBB
		OLED_WRITE_DATA_UINT16(B | (G << 6) | (R << 11));
	    }
	}
	++frame;
    }
    return 0;
}
