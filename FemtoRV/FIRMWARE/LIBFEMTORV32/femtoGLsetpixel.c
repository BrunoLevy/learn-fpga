#include <femtorv32.h>

void GL_setpixel(int x, int y, uint16_t color) {
    oled_write_window(x,y,x,y);
    OLED_WRITE_DATA_UINT16(color);
}

