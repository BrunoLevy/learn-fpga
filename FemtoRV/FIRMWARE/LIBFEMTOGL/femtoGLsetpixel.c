#include <femtoGL.h>

void GL_setpixel(int x, int y, uint16_t color) {
    GL_write_window(x,y,x,y);
    GL_WRITE_DATA_UINT16(color);
}

