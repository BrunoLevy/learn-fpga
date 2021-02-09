// Testing the OLED screen, displaying an animated pattern with
// all the 65K colors.

#include <femtoGL.h>


int main() {
    GL_init(GL_MODE_CHOOSE_RGB);
    GL_clear();
    int frame = 0;
    for(;;) {
        GL_write_window(0,0,GL_width-1,GL_height-1);
	for(uint32_t y=0; y<GL_height; ++y) {
	    for(uint32_t x=0; x<GL_width; ++x) {
		uint32_t R = (x+frame) & 63;
		uint32_t G = (x >> 3)  & 63;
		uint32_t B = (y+frame) & 63;
	        // pixel color: RRRRR GGGGG 0 BBBBB
		GL_WRITE_DATA_UINT16(B | (G << 6) | (R << 11));
	    }
	}
	++frame;
    }
    return 0;
}
