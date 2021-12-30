#include "lite_fb.h"
#include <string.h>


/*
 * fb_clear(), fb_fillrect() and fb_fill_poly() can be made *much faster* by 
 * adding a very crude "blitter" to the LiteX SOC. The Blitter can fill a
 * contiguous zone of memory with a 32 bit value using DMA (much faster than
 * with the CPU !). When the Blitter is declared, then CSR_BLITTER_BASE is
 * defined in <generated/csr.h>. Else a (much slower) software fallback is
 * used.
 * 
 * class Blitter(Module, AutoCSR):
 *     def __init__(self,port): # port = self.sdram.crossbar.get_port()
 *         self._value = CSRStorage(32)
 *         from litedram.frontend.dma import LiteDRAMDMAWriter
 *         dma_writer = LiteDRAMDMAWriter(
 *             port=port,fifo_depth=16,fifo_buffered=False,with_csr=True
 *         )
 *         self.submodules.dma_writer = dma_writer
 *         self.comb += dma_writer.sink.data.eq(self._value.storage)
 *         self.comb += dma_writer.sink.valid.eq(1)
 * 
 *  ....
 * 
 *     if with_video_framebuffer:
 *          self.add_video_framebuffer(
 *              phy=self.videophy, timings="640x480@75Hz", 
 *              format="rgb888", clock_domain="hdmi"
 *          )
 *          blitter = Blitter(port=self.sdram.crossbar.get_port())
 *          self.submodules.blitter = blitter
 *  ...
 */ 

#define FB_MIN(x,y) ((x) < (y) ? (x) : (y))
#define FB_MAX(x,y) ((x) > (y) ? (x) : (y))
#define FB_SGN(x)   (((x) > (0)) ? 1 : ((x) ? -1 : 0))

uint32_t* fb_base = (uint32_t*)FB_PAGE1;

#ifdef CSR_VIDEO_FRAMEBUFFER_BASE

void fb_set_read_page(uint32_t addr) {
    video_framebuffer_dma_base_write(addr);
}

void fb_set_write_page(uint32_t addr) {
    fb_base = (uint32_t*)addr;
}

void fb_on(void) {
    video_framebuffer_vtg_enable_write(1);
    video_framebuffer_dma_enable_write(1);
}

void fb_off(void) {
    video_framebuffer_vtg_enable_write(0);
    video_framebuffer_dma_enable_write(0);
}


int fb_init(void) {
    fb_off();
    fb_set_read_page(FB_PAGE1);
    fb_set_write_page(FB_PAGE1);
    fb_clear();
    fb_on();
    fb_set_cliprect(0,0,FB_WIDTH-1,FB_HEIGHT-1);
    fb_set_poly_mode(FB_POLY_FILL);
    fb_set_poly_culling(FB_POLY_NO_CULLING);
    return 1;
}

void fb_clear(void) {
#ifdef CSR_BLITTER_BASE
    blitter_value_write(0x000000);
    blitter_dma_writer_base_write((uint32_t)(fb_base));
    blitter_dma_writer_length_write(FB_WIDTH*FB_HEIGHT*4);
    blitter_dma_writer_enable_write(1);
    while(!blitter_dma_writer_done_read());
    blitter_dma_writer_enable_write(0);    
#else
    memset((void*)fb_base, 0, FB_WIDTH*FB_HEIGHT*4);
#endif    
}

#else

void     fb_set_read_page(uint32_t addr) {}
void     fb_set_write_page(uint32_t addr) {}
int      fb_init(void) { return 0; }
void     fb_on(void) {}
void     fb_off(void) {}
void     fb_clear(void) {}

#endif

/*****************************************************************************/

void fb_set_dual_buffering(int doit) {
   if(doit) {
      fb_set_write_page(FB_PAGE2);
      fb_clear();
   } else {
      fb_set_read_page(FB_PAGE1);
      fb_set_write_page(FB_PAGE1);
   }
}

void fb_swap_buffers(void) {
   flush_l2_cache();
   if((uint32_t)fb_base == FB_PAGE1) {
      fb_set_read_page(FB_PAGE1);
      fb_set_write_page(FB_PAGE2);
   } else {
      fb_set_read_page(FB_PAGE2);
      fb_set_write_page(FB_PAGE1);
   }
}

/******************************************************************************/

static int fb_clip_x1 = 0;
static int fb_clip_y1 = 0;
static int fb_clip_x2 = FB_WIDTH-1;
static int fb_clip_y2 = FB_HEIGHT-1;

void fb_set_cliprect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
    fb_clip_x1 = x1;
    fb_clip_y1 = y1;
    fb_clip_x2 = x2;
    fb_clip_y2 = y2;    
}

/******************************************************************************/

static inline void fb_hline_no_wait_dma(uint32_t* pix_start, uint32_t len, uint32_t RGB) {
#ifdef CSR_BLITTER_BASE
    blitter_value_write(RGB);
    blitter_dma_writer_base_write((uint32_t)(pix_start));
    blitter_dma_writer_length_write(len*4);
    blitter_dma_writer_enable_write(1);
#else
    for(uint32_t i=0; i<len; ++i) {
	*pix_start = RGB;
	++pix_start;
    }
#endif    
}

static inline void fb_hline_wait_dma(void) {
#ifdef CSR_BLITTER_BASE   
    while(!blitter_dma_writer_done_read());
    blitter_dma_writer_enable_write(0);    
#endif
}

static inline void fb_hline(uint32_t* pix_start, uint32_t len, uint32_t RGB) {
   fb_hline_no_wait_dma(pix_start, len, RGB);
   fb_hline_wait_dma();
}

void fb_fillrect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint32_t RGB
) {
    uint32_t w = x2-x1+1;
    uint32_t* line_ptr = fb_pixel_address(x1,y1);
    for(int y=y1; y<=y2; ++y) {
	uint32_t* pix_ptr = line_ptr;
	fb_hline(pix_ptr,w,RGB);
	line_ptr += FB_WIDTH;
    }
}

/******************************************************************************/

#define INSIDE 0
#define LEFT   1
#define RIGHT  2
#define BOTTOM 4
#define TOP    8

#define code(x,y) ((x) < fb_clip_x1) | (((x) > fb_clip_x2)<<1) | (((y) < fb_clip_y1)<<2) | (((y) > fb_clip_y2)<<3) 

void fb_line(int x1, int y1, int x2, int y2, uint32_t RGB) {
   
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
	    x = x1 + (x2 - x1) * (fb_clip_y2 - y1) / (y2 - y1); 
	    y = fb_clip_y2; 
	} else if (codeout & BOTTOM) { 
	    x = x1 + (x2 - x1) * (fb_clip_y1 - y1) / (y2 - y1); 
	    y = fb_clip_y1; 
	}  else if (codeout & RIGHT) { 
	    y = y1 + (y2 - y1) * (fb_clip_x2 - x1) / (x2 - x1); 
	    x = fb_clip_x2; 
	} else if (codeout & LEFT) { 
	    y = y1 + (y2 - y1) * (fb_clip_x1 - x1) / (x2 - x1); 
	    x = fb_clip_x1; 
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
	    fb_setpixel(x,y,RGB);
	    y += sy;
	    while(ex >= 0)  {
		fb_setpixel(x,y,RGB);		
		x += sx;
		ex -= dy << 1;
	    }
	    ex += dx << 1;
	}
    } else {
	int ey = (dy << 1) - dx;
	for(int u=0; u<dx; u++) {
	    fb_setpixel(x,y,RGB);
	    x += sx;
	    while(ey >= 0) {
		fb_setpixel(x,y,RGB);
		y += sy;
		ey -= dx << 1;
	    }
	    ey += dy << 1;
	}
    }
}

/************************************************************************************/

static PolyMode fb_poly_mode = FB_POLY_FILL;
void fb_set_poly_mode(PolyMode mode) { fb_poly_mode = mode; }

static PolyCulling fb_poly_culling = FB_POLY_NO_CULLING;
void fb_set_poly_culling(PolyCulling culling) { fb_poly_culling = culling; }

/************************************************************************************/


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
    int prev_status = FB_SGN(a*prev_x + b*prev_y +c);

    for(int i=0; i<nb_pts; ++i) {
	int x = buff1[2*i];
	int y = buff1[2*i+1];
	int status = FB_SGN(a*x + b*y + c);
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
static int fb_clip(int nb_pts, int** poly) {
    static int  buff1[20];    
    int  buff2[20];
    nb_pts = clip_H(nb_pts, *poly, buff2, 1, 0, fb_clip_x1);
    nb_pts = clip_H(nb_pts, buff2, buff1,-1, 0, fb_clip_x2);
    nb_pts = clip_H(nb_pts, buff1, buff2, 0, 1, fb_clip_y1);
    nb_pts = clip_H(nb_pts, buff2, buff1, 0,-1, fb_clip_y2);
    *poly = buff1;
    return nb_pts;
}

void fb_fill_poly(uint32_t nb_pts, int* points, uint32_t RGB) {
    static uint32_t x_left[FB_HEIGHT];
    static uint32_t x_right[FB_HEIGHT];

    /* Determine clockwise, miny, maxy */
    int clockwise = 0;
    int minx =  10000;
    int maxx = -10000;
    int miny =  10000;
    int maxy = -10000;
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
	minx = FB_MIN(minx,x1);
	maxx = FB_MAX(maxx,x1);
	miny = FB_MIN(miny,y1);
	maxy = FB_MAX(maxy,y1);
    }

    /* culling */
    if((fb_poly_culling == FB_POLY_CW) && (clockwise < 0)) {
	return;
    }
    if((fb_poly_culling == FB_POLY_CCW) && (clockwise > 0)) {
	return;
    }

    /* clipping */
    if((minx < fb_clip_x1) || (miny < fb_clip_y1) || (maxx > fb_clip_x2) || (maxy > fb_clip_y2)) {
	nb_pts = fb_clip(nb_pts, (int**)&points);
	miny =  10000;
	maxy = -10000;
	for(int i1=0; i1<nb_pts; ++i1) {
	    // int x1 = points[2*i1];
	    int y1 = points[2*i1+1];
	    miny = FB_MIN(miny,y1);
	    maxy = FB_MAX(maxy,y1);
	}
    }

    /* Determine x_left and x_right for each scaline */
    for(int i1=0; i1<nb_pts; ++i1) {
	int i2=(i1==nb_pts-1) ? 0 : i1+1;

	int x1 = points[2*i1];
	int y1 = points[2*i1+1];
	int x2 = points[2*i2];
	int y2 = points[2*i2+1];

	if(fb_poly_mode == FB_POLY_LINES) {
	    fb_line(x1,y1,x2,y2,RGB);
	    continue;
	}

	uint32_t* x_buffer = ((clockwise > 0) ^ (y2 > y1)) ? x_left : x_right;
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
	  x_left[y1]  = FB_MIN(x1,x2);
	  x_right[y1] = FB_MAX(x1,x2);
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

    if(fb_poly_mode == FB_POLY_LINES) {    
	return;
    }

    uint32_t* line_ptr = (uint32_t*)(fb_base) + miny * FB_WIDTH;
    for(int y = miny; y <= maxy; ++y) {
	int x1 = x_left[y];
	int x2 = x_right[y];
        // swap x1,x2 (may happen with non-convex polygons)
        if(x2 < x1) { 
	   x1 = x1 ^ x2;
	   x2 = x2 ^ x1;
	   x1 = x1 ^ x2;
	}
        if(y != miny) fb_hline_wait_dma();
        fb_hline_no_wait_dma(line_ptr+x1, x2-x1+1, RGB);
	line_ptr += FB_WIDTH;
    }
    fb_hline_wait_dma();
}

/******************************************************************************/


