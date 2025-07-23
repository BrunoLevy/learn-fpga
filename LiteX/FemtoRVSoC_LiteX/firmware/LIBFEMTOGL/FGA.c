#include <femtoGL.h>

extern int GL_clip(
    int nb_pts, int** poly, 
    int xmin, int ymin, int xmax, int ymax
);

#define BIG 16384;

#define WIDTH  FGA_width
#define HEIGHT FGA_height

static inline void FGA_fill_rect_fast(
  uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
   if(x2 < x1) {
      return;
   }
   FGA_CMD2(FGA_CMD_SET_WWINDOW_X, x1, x2);
   FGA_CMD2(FGA_CMD_SET_WWINDOW_Y, y1, y2);
   FGA_CMD1(FGA_CMD_FILLRECT, color);
}

static inline FGA_wait_GPU() {
   while(IO_IN(IO_FGA_CNTL) & FGA_BUSY_bit);
}

void FGA_fill_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
   FGA_fill_rect_fast(x1, y1, x2, y2, color);
   FGA_wait_GPU();
}

void FGA_clear() {
    FGA_fill_rect(0,0,WIDTH,HEIGHT,GL_bg);
}

void FGA_wait_vbl() {
   while(!(IO_IN(IO_FGA_CNTL) & FGA_VBL_bit));
}



#define INSIDE 0
#define LEFT   1
#define RIGHT  2
#define BOTTOM 4
#define TOP    8

#define XMIN 0
#define XMAX (WIDTH-1)
#define YMIN 0
#define YMAX (HEIGHT-1)

#define code(x,y) ((x) < XMIN) | (((x) > XMAX)<<1) | (((y) < YMIN)<<2) | (((y) > YMAX)<<3) 

// Not super fast, could write to mem directly instead (but then we
// do not benefit from mode-independent abstraction and need to do
// that on our own).
static inline void FGA_setpixel_fast(int x, int y, uint16_t color) {
  FGA_CMD2(FGA_CMD_SET_WWINDOW_X, x, x);
  FGA_CMD2(FGA_CMD_SET_WWINDOW_Y, y, y);
  IO_OUT(IO_FGA_DAT,color);
}

void FGA_setpixel(int x, int y, uint16_t color) {
   FGA_setpixel_fast(x,y,color);
}

void FGA_line(int x1, int y1, int x2, int y2, uint16_t color) {
    /* Cohen-Sutherland line clipping. */
    int code1 = code(x1,y1);
    int code2 = code(x2,y2);
    int codeout;
    int x,y,dx,dy,sx,sy;

    for(;;) {
	/* Both points inside. */
	if(code1 == 0 && code2 == 0) {
	    break;
	}

	/* No point inside. */
	if(code1 & code2) {
	    return;
	}

	/* One of the points is outside. */
	codeout = code1 ? code1 : code2;

	/* Compute intersection. */
	if (codeout & TOP) { 
	    x = x1 + (x2 - x1) * (YMAX - y1) / (y2 - y1); 
	    y = YMAX; 
	} else if (codeout & BOTTOM) { 
	    x = x1 + (x2 - x1) * (YMIN - y1) / (y2 - y1); 
	    y = YMIN; 
	}  else if (codeout & RIGHT) { 
	    y = y1 + (y2 - y1) * (XMAX - x1) / (x2 - x1); 
	    x = XMAX; 
	} else if (codeout & LEFT) { 
	    y = y1 + (y2 - y1) * (XMIN - x1) / (x2 - x1); 
	    x = XMIN; 
	} 
	
	/* Replace outside point with intersection. */
	if (codeout == code1) { 
	    x1 = x; 
	    y1 = y;
	    code1 = code(x1,y1);
	} else { 
	    x2 = x; 
	    y2 = y;
	    code2 = code(x2,y2);
	}
    }
    
    /* Bresenham line drawing. */
    dy = y2 - y1;
    sy = 1;
    if(dy < 0) {
	sy = -1;
	dy = -dy;
    }

    dx = x2 - x1;
    sx = 1;
    if(dx < 0) {
	sx = -1;
	dx = -dx;
    }

    x = x1;
    y = y1;
    if(dy > dx) {
	int ex = (dx << 1) - dy;
	for(int u=0; u<dy; u++) {
	    FGA_setpixel_fast(x,y,color);
	    y += sy;
	    while(ex >= 0)  {
		FGA_setpixel_fast(x,y,color);		
		x += sx;
		ex -= dy << 1;
	    }
	    ex += dx << 1;
	}
    } else {
	int ey = (dy << 1) - dx;
	for(int u=0; u<dx; u++) {
	    FGA_setpixel_fast(x,y,color);
	    x += sx;
	    while(ey >= 0) {
		FGA_setpixel_fast(x,y,color);
		y += sy;
		ey -= dx << 1;
	    }
	    ey += dy << 1;
	}
    }
}

void FGA_fill_poly(int nb_pts, int* points, uint16_t color) {

    uint16_t x_left[HEIGHT];
    uint16_t x_right[HEIGHT];

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

	if(gl_polygon_mode == GL_POLY_LINES) {
	    FGA_line(x1,y1,x2,y2,color);
	    continue;
	}

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

    if(gl_polygon_mode == GL_POLY_LINES) {    
        return;
    }

    for(int y = miny; y <= maxy; ++y) {
	int x1 = x_left[y];
	int x2 = x_right[y];
	/* 
	 * By waiting *before* instead of *after*, we can overlap
	 * fetchting next x1,x2 and drawing the line (negligible in
	 * fact, but better than nothing.
	 */
        FGA_wait_GPU();       
        FGA_fill_rect_fast(x1,y,x2,y, color);
    }
    FGA_wait_GPU();
}

