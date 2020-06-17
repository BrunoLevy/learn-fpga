#include <femtorv32.h>

void GL_fill_poly(int nb_pts, int* points, uint16_t color) {

    static char x_left[128];
    static char x_right[128];

    /* Determine clockwise, miny, maxy */
    int clockwise = 0;
    int miny =  256;
    int maxy = -256;
    for(int i1=0; i1<nb_pts; ++i1) {
	int i2=(i1==nb_pts-1) ? 0 : i1+1;
	int i3=(i2==nb_pts-1) ? 0 : i2+1;
	int x1 = points[2*i1];
	int y1 = points[2*i1+1];
	int dx1 = points[2*i2]   - x1;
	int dy1 = points[2*i2+1] - y1;
	int dx2 = points[2*i3]   - x1;
	int dy2 = points[2*i3+1] - y1;
	clockwise += dx1 * dy2 - dx2 * dy1;
	miny = MIN(miny,y1);
	maxy = MAX(maxy,y1);
    }

    /* Determine x_left and x_right for each scaline */
    for(int i1=0; i1<nb_pts; ++i1) {
	int i2=(i1==nb_pts-1) ? 0 : i1+1;
	int x1 = points[2*i1];
	int y1 = points[2*i1+1];
	int x2 = points[2*i2];
	int y2 = points[2*i2+1];
	char* x_buffer = (clockwise > 0) ^ (y2 > y1) ? x_left : x_right;
	int dx = x2 - x1;
	int sx = 1;
	int dy = y2 - y1;
	int sy = 1;
	int x = x1;
	int y = y1;
	int ex;
	
	if(dx < 0) {
	    sx = -1;
	    dx = -dx;
	}
	
	if(dy < 0) {
	    sy = -1;
	    dy = -dy;
	}

	if(y1 == y2) {
	    continue;
	}

	ex = (dx << 1) - dy;

	for(int u=0; u <= dy; ++u) {
	    x_buffer[y] = x;
	    y += sy;
	    while(ex >= 0) {
		x += sx;
		ex -= dy << 1;
	    }
	    ex += dx << 1;
	}
    }

    for(int y = miny; y <= maxy; ++y) {
	int x1 = x_left[y];
	int x2 = x_right[y];
	oled_write_window(x1,y,x2,y);
	for(int x=x1; x<=x2; ++x) {
	    IO_OUT(IO_OLED_DATA,color >> 8);
	    OLED_WAIT();
	    IO_OUT(IO_OLED_DATA,color);
	    OLED_WAIT();
	}
    }
    
}
