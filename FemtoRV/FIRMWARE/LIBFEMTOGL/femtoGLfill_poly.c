#include <femtoGL.h>

int gl_polygon_mode = GL_POLY_FILL;
int gl_culling_mode = GL_FRONT_AND_BACK;

/** 
 * \brief Clips a polygon by a half-plane.
 * \param[in] number of vertices of the input polygon.
 * \param[in] buff1 vertices of the input polygon.
 * \param[out] buff2 vertices of the resulting polygon.
 * \param[in] a , b , c equation of the half-plane: ax + by + c >= 0
 * \return number of vertices in resulting polygon.
 */
static int clip_H(
    int nb_pts, int* buff1, int* buff2, int a, int b, int c
) {
    if(nb_pts == 0) {
	return 0;
    }

    if(nb_pts == 1) {
	if(a*buff1[0] + b*buff1[1] + c >= 0) {
	    buff2[0] = buff1[0];
	    buff2[1] = buff1[1];
	    return 1;
	} else {
	    return 0;
	}
    }

    int nb_result = 0;
    int prev_x = buff1[2*(nb_pts-1)];
    int prev_y = buff1[2*(nb_pts-1)+1];
    int prev_status = SGN(a*prev_x + b*prev_y +c);

    for(int i=0; i<nb_pts; ++i) {
	int x = buff1[2*i];
	int y = buff1[2*i+1];
	int status = SGN(a*x + b*y + c);
	if(status != prev_status && status != 0 && prev_status != 0) {

	    /*
	     * Remember, femtorv32 does not always have hardware mul,
	     * so we replace the following code with two switches
	     * (a and b take values in -1,0,1, no need to mul).
	     * int t_num   = -a*prev_x-b*prev_y-c;
	     * int t_denom = a*(x - prev_x) + b*(y - prev_y);
	     */

	    int t_num = -c;
	    int t_denom = 0;
	    
	    switch(a) {
	    case -1:
		t_num += prev_x;
		t_denom -= (x - prev_x);
		break;
	    case  1:
		t_num -= prev_x;
		t_denom += (x - prev_x);
		break;
	    }

	    switch(b) {
	    case -1:
		t_num += prev_y;
		t_denom -= (y - prev_y);
		break;
	    case  1:
		t_num -= prev_y;
		t_denom += (y - prev_y);
		break;
	    }
	    
	    int Ix = prev_x + t_num * (x - prev_x) / t_denom;
	    int Iy = prev_y + t_num * (y - prev_y) / t_denom;
	    buff2[2*nb_result]   = Ix;
	    buff2[2*nb_result+1] = Iy;
	    ++nb_result;
	}
	if(status >= 0) {
	    buff2[2*nb_result]   = x;
	    buff2[2*nb_result+1] = y;
	    ++nb_result;
	}
	prev_x = x;
	prev_y = y;
	prev_status = status;
    }

    return nb_result;
}

/**
 * \brief Clips a polygon by the screen.
 * \param[in] number of vertices of the input polygon.
 * \param[in,out] poly vertices of the polygon.
 * \return number of vertices in the result polygon.
 */
int GL_clip(
    int nb_pts, int** poly, 
    int xmin, int ymin, int xmax, int ymax
) {
    static int  buff1[20];    
    int  buff2[20];
    nb_pts = clip_H(nb_pts, *poly, buff2, 1, 0, xmin);
    nb_pts = clip_H(nb_pts, buff2, buff1,-1, 0, xmax);
    nb_pts = clip_H(nb_pts, buff1, buff2, 0, 1, ymin);
    nb_pts = clip_H(nb_pts, buff2, buff1, 0,-1, ymax);
    *poly = buff1;
    return nb_pts;
}

void GL_fill_poly(int nb_pts, int* points, uint16_t color) {
#ifdef FGA   
    if(FGA_mode != GL_MODE_OLED) {
       FGA_fill_poly(nb_pts, points, color);
       return;
    }
#endif  
    char x_left[128];
    char x_right[128];

    /* Determine clockwise, miny, maxy */
    int clockwise = 0;
    int minx =  256;
    int maxx = -256;
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
   
    if((minx < 0) || (miny < 0) || (maxx >= GL_width) || (maxy >= GL_height)) {
	nb_pts = GL_clip(nb_pts, &points, 0, 0, GL_width-1, GL_height-1);
	miny =  256;
	maxy = -256;
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
	    GL_line(x1,y1,x2,y2,color);
	    continue;
	}

	char* x_buffer = ((clockwise > 0) ^ (y2 > y1)) ? x_left : x_right;
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
    	    if(y > 0 && y < 256) x_buffer[y] = x; // HERE
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
	GL_write_window(x1,y,x2,y);
	for(int x=x1; x<=x2; ++x) {
	    GL_WRITE_DATA_UINT16(color);
	}
    }
    
}
