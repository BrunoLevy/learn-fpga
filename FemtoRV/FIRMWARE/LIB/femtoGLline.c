#include <femtorv32.h>

void GL_line(int x1, int y1, int x2, int y2, uint16_t color) {

    int dy = y2 - y1;
    int sy = 1;
    if(dy < 0) {
	sy = -1;
	dy = -dy;
    }

    int dx = x2 - x1;
    int sx = 1;
    if(dx < 0) {
	sx = 1;
	dx = -dx;
    }
    
    int x = x1;
    int y = y1;
    if(dy > dx) {
	int ex = (dx << 1) - dy;
	for(int u=0; u<dy; u++) {
	    GL_setpixel(x,y,color);
	    y += sy;
	    while(ex >= 0)  {
		GL_setpixel(x,y,color);		
		x += sx;
		ex -= dy << 1;
	    }
	    ex += dx << 1;
	}
    } else {
	int ey = (dy << 1) - dx;
	for(int u=0; u<dx; u++) {
	    GL_setpixel(x,y,color);
	    x += sx;
	    while(ey >= 0) {
		GL_setpixel(x,y,color);
		y += sy;
		ey -= dx << 1;
	    }
	    ey += dy << 1;
	}
    }
}
