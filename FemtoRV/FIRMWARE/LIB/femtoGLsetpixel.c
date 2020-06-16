#include <femtorv32.h>

void GL_setpixel(int x, int y, uint16_t color) {
    oled_write_window(x,y,x,y);
    IO_OUT(IO_OLED_DATA,color >> 8);
    oled_wait(); 
    IO_OUT(IO_OLED_DATA,color);
    oled_wait();
}



