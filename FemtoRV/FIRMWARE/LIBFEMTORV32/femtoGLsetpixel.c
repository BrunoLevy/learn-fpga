#include <femtorv32.h>

void GL_setpixel(int x, int y, uint16_t color) {
    oled_write_window(x,y,x,y);
    IO_OUT(IO_OLED_DATA,color >> 8);
    OLED_WAIT();
    IO_OUT(IO_OLED_DATA,color);
    OLED_WAIT();
}



