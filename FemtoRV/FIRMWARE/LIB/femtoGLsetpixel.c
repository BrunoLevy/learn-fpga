#include <femtorv32.h>

void GL_setpixel(int x, int y, uint16_t color) {
    if(x < 0 || x > 127 || y < 0 || y > 127) {
	return;
    }
    oled_write_window(x,y,x,y);
    IO_OUT(IO_OLED_DATA,color >> 8);
    oled_wait(); 
    IO_OUT(IO_OLED_DATA,color);
    oled_wait();
}

void GL_setpixel_RGB(int x, int y, uint8_t r, uint8_t g, uint8_t b) {
    GL_setpixel(x,y,GL_RGB(r,g,b));
}


