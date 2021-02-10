#include <femtoGL.h>

#define INSIDE 0
#define LEFT   1
#define RIGHT  2
#define BOTTOM 4
#define TOP    8

#define XMIN 0
#define XMAX (GL_width-1)
#define YMIN 0
#define YMAX (GL_height-1)

#define code(x,y) ((x) < XMIN) | (((x) > XMAX)<<1) | (((y) < YMIN)<<2) | (((y) > YMAX)<<3) 

void GL_line(int x1, int y1, int x2, int y2, uint16_t color) {

#ifdef FGA   
    if(FGA_mode != -1) {
      FGA_line(x1, y1, x2, y2, color);
      return;
    }
#endif
   
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
