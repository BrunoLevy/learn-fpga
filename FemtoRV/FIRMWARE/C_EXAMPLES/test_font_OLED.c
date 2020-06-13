// Testing the OLED screen, displaying the font map.

#include <femtorv32.h>

extern int GL_putchar(int);

int main() {

    GL_tty_init();

    oled_init();
    oled_clear();
    oled_wait();
   
    int frame=0;
   
    for(;;) {
	oled2(0x15,0x00,0x7f); // column address
	oled2(0x75,0x00,0x7f); // row address
	oled0(0x5c);           // write RAM

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
		IO_OUT(IO_OLED_DATA,BW & ((G>>2)|(R<<3)));
	        oled_wait();
		IO_OUT(IO_OLED_DATA,BW & (B|(G << 6)));
	        oled_wait();
	       
	        //IO_OUT(IO_OLED_DATA,BW);
	        //oled_wait();
		//IO_OUT(IO_OLED_DATA,BW);
	        //oled_wait();
	    }
	}
	++frame;
    }
    return 0;
}
