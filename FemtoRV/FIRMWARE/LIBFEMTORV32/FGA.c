#include <femtorv32.h>

extern int GL_clip(
    int nb_pts, int** poly, 
    int xmin, int ymin, int xmax, int ymax
);

#define BIG 16384;
#define WIDTH  320
#define HEIGHT 200

void FGA_fill_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
    oled_write_window(x1,y1,x2,y2);
    for(int y=y1; y<=y2; ++y) {
	for(int x=x1; x<=x2; ++x) {
	   IO_OUT(IO_FGA_DAT, color);	   
	}
    }
}

void FGA_clear() {
    FGA_fill_rect(0,0,WIDTH,HEIGHT,GL_bg);
}

void FGA_wait_vbl() {
   while(!(IO_IN(IO_FGA_CNTL) & (1 << 31)));
}

void FGA_fill_poly(int nb_pts, int* points, uint16_t color) {

    uint16_t x_left[WIDTH];
    uint16_t x_right[WIDTH];

    /* Determine clockwise, miny, maxy */
    int clockwise = 0;
    int minx =  BIG;
    int maxx = -BIG;
    int miny =  BIG;
    int maxy = -BIG;
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
	minx = MIN(minx,x1);
	maxx = MAX(maxx,x1);
	miny = MIN(miny,y1);
	maxy = MAX(maxy,y1);
    }

    if((gl_culling_mode == GL_FRONT_FACE) && (clockwise < 0)) {
	return;
    }

    if((gl_culling_mode == GL_BACK_FACE) && (clockwise > 0)) {
	return;
    }
    
    if((minx < 0) || (miny < 0) || (maxx >= WIDTH) || (maxy >= HEIGHT)) {
	nb_pts = GL_clip(nb_pts, &points, 0, 0, WIDTH-1, HEIGHT-1);
	miny =  BIG;
	maxy = -BIG;
	for(int i1=0; i1<nb_pts; ++i1) {
	    int x1 = points[2*i1];
	    int y1 = points[2*i1+1];
	    miny = MIN(miny,y1);
	    maxy = MAX(maxy,y1);
	}
    }
    
    /* Determine x_left and x_right for each scaline */
    for(int i1=0; i1<nb_pts; ++i1) {
	int i2=(i1==nb_pts-1) ? 0 : i1+1;

	int x1 = points[2*i1];
	int y1 = points[2*i1+1];
	int x2 = points[2*i2];
	int y2 = points[2*i2+1];

        //TODO...
	//if(gl_polygon_mode == GL_POLY_LINES) {
	    // GL_line(x1,y1,x2,y2,color);
	    // continue;
	//}

        uint16_t* x_buffer = ((clockwise > 0) ^ (y2 > y1)) ? x_left : x_right;
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
	   x_left[y1]  = MIN(x1,x2);
	   x_right[y1] = MAX(x1,x2);
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

    //TODO
    //if(gl_polygon_mode == GL_POLY_LINES) {    
    //	return;
    //}

    for(int y = miny; y <= maxy; ++y) {
	int x1 = x_left[y];
	int x2 = x_right[y];
	FGA_write_window(x1,y,x2,y);
        for(int x=x1; x<=x2; ++x) {
	   IO_OUT(IO_FGA_DAT, color);
	}
    }
}

