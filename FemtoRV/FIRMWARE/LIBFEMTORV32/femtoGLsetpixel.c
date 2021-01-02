#include <femtorv32.h>

void GL_setpixel(int x, int y, uint16_t color) {
    oled_write_window(x,y,x,y);
    IO_OUT(IO_SSD1351_DAT,color >> 8);
    IO_OUT(IO_SSD1351_DAT,color);
}



