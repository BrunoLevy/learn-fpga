#include <femtorv32.h>

uint16_t GL_fg = 0xffff;
uint16_t GL_bg = 0x0000;

void GL_set_fg(uint8_t r, uint8_t g, uint8_t b) {
    GL_fg = (uint16_t)GL_RGB((uint16_t)(r), (uint16_t)(g), (uint16_t)(b));
}

void GL_set_bg(uint8_t r, uint8_t g, uint8_t b) {
    GL_bg = (uint16_t)GL_RGB((uint16_t)(r), (uint16_t)(g), (uint16_t)(b));
}

void GL_fill_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
    uint32_t lo = (uint32_t)color;    
    uint32_t hi = color >> 8;
    oled_write_window(x1,y1,x2,y2);
    for(int y=y1; y<=y2; ++y) {
	for(int x=x1; x<=x2; ++x) {
	   IO_OUT(IO_OLED_DATA,hi);
	   oled_wait();
	   IO_OUT(IO_OLED_DATA,lo);
	   oled_wait();
	}
    }
}

void GL_clear() {
    GL_fill_rect(0,0,127,127,GL_bg);
}

		
