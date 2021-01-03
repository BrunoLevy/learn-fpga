// Testing the OLED screen, displaying the font map.

#include <femtorv32.h>

extern int GL_putchar(int);

int main() {
   
    GL_init();
    GL_clear();
   
    int frame=0;
   
    for(;;) {
        oled_write_window(0,0,127,127);
	for(uint32_t y=0; y<128; ++y) {
	    for(uint32_t x=0; x<128; ++x) {
	        uint32_t car_x = (x + frame)/8;
	        uint32_t car_y = (y + frame)/8;
	        uint32_t car = (car_y * (128/8) + car_x) & 127;

	        uint32_t col = (x + frame)%8;
	        uint32_t row = (y + frame)%8;
	       
	        uint32_t BW = (font_8x8[car*8+col] & (1 << row)) ? 255 : 0;
	       
		uint32_t R = (y+frame)  & 63;
		uint32_t G = (y >> 3)   & 63;
		uint32_t B = (-y+frame) & 63;
	       
		// pixel color: RRRRR GGGGG 0 BBBBB
		OLED_WRITE_DATA_UINT8_UINT8(BW & ((G>>2)|(R<<3)), BW & (B|(G << 6)));
	    }
	}
	++frame;
    }
    return 0;
}
