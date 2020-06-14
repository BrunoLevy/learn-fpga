#include <femtorv32.h>

void oled_clear_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2
) {
    oled_write_window(x1,y1,x2,y2);
    for(int y=y1; y<=y2; ++y) {
	for(int x=x1; x<=x2; ++x) {
	   IO_OUT(IO_OLED_DATA,0);
	   oled_wait();
	   IO_OUT(IO_OLED_DATA,0);
	   oled_wait();
	}
    }
}

void oled_clear() {
    oled_clear_rect(0,0,127,127);
}

		
