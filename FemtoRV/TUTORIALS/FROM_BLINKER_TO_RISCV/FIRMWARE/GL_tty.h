/**
 * ansi_graphics.h
 * A couple of function to display graphics in the terminal, 
 * using ansi sequences.
 * Bruno Levy, Jan 2024
 */

#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>

#ifndef GL_FPS
#define GL_FPS 30
#endif

#if defined(__linux__) || defined(_WIN32) || defined(__APPLE__)
#define BIGCPU  // we are compiling for a real machine
#else
#define TINYCPU // we are compiling for a softwore
#endif

#ifdef __linux__
#include <unistd.h> // for usleep()
#endif

// You can define GL_width and GL_height before
// #including ansi_graphics.h in case the plain
// old 80x25 pixels does not suffice.

#ifndef GL_width
#define GL_width  80
#endif

#ifndef GL_height
#define GL_height 25
#endif

/**
 * \brief Sets the current graphics position
 * \param[in] x typically in 0,79
 * \param[in] y typically in 0,24
 */
static inline void GL_gotoxy(int x, int y) {
    printf("\033[%d;%dH",y,x);
}

/**
 * \brief Sets the current graphics position
 * \param[in] R , G , B the RGB color of the pixel, in [0..255]
 * \details Typically used by programs that draw all pixels sequentially,
 *  like a raytracer. After each line, one can either printf("\n") or
 *  call GL_gotoxy(). If you want to draw individual pixels in an
 *  arbitrary order, use GL_setpixelRGB(x,y,R,G,B)
 */
static inline void GL_setpixelRGBhere(uint8_t R, uint8_t G, uint8_t B) {
    // set background color, print space 
    printf("\033[48;2;%d;%d;%dm ",(int)R,(int)G,(int)B); 
}


/**
 * \brief Draws two "pixels" at the current
 *  cursor position and advances the current cursor
 *  position.
 * \details Characters are roughly twice as high as wide.
 *  To generate square pixels, this function draws two pixels in
 *  the same character, using the special lower-half white / upper-half
 *  black character, and setting the background and foreground colors.
 */
static inline void GL_set2pixelsRGBhere(
    uint8_t r1, uint8_t g1, uint8_t b1,
    uint8_t r2, uint8_t g2, uint8_t b2
) {
    if((r2 == r1) && (g2 == g1) && (b2 == b1)) {
	GL_setpixelRGBhere(r1,g1,b1);
    } else {
	printf("\033[48;2;%d;%d;%dm",(int)r1,(int)g1,(int)b1);	   	   
	printf("\033[38;2;%d;%d;%dm",(int)r2,(int)g2,(int)b2);
	// https://www.w3.org/TR/xml-entity-names/025.html
	// https://onlineunicodetools.com/convert-unicode-to-utf8
	// https://copypastecharacter.com/
	printf("\xE2\x96\x83");
    }
}

#define GL_RGB(R,G,B) #R ";" #G ";" #B 

static inline void GL_setpixelIhere(
    const char** cmap, int c
) {
    // set background color, print space 
    printf("\033[48;2;%sm ",cmap[c]); 
}

static inline void GL_set2pixelsIhere(
    const char** cmap, int c1, int c2
) {
    if(c1 == c2) {
	GL_setpixelIhere(cmap, c1);
    } else {
	printf("\033[48;2;%sm",cmap[c1]);	   	   
	printf("\033[38;2;%sm",cmap[c2]);
	// https://www.w3.org/TR/xml-entity-names/025.html
	// https://onlineunicodetools.com/convert-unicode-to-utf8
	// https://copypastecharacter.com/
	printf("\xE2\x96\x83");
    }
}

/**
 * \brief Moves the cursor position to the next line.
 * \details Background and foreground colors are set to black.
 */
static inline void GL_newline() {
    printf("\033[38;2;0;0;0m");	   
    printf("\033[48;2;0;0;0m\n");
}

/**
 * \brief Sets the color of a pixel
 * \param[in] x typically in 0,79
 * \param[in] y typically in 0,24
 * \param[in] R , G , B the RGB color of the pixel, in [0..255]
 */
static inline void GL_setpixelRGB(
    int x, int y, uint8_t R, uint8_t G, uint8_t B
) {
    GL_gotoxy(x,y);
    GL_setpixelRGBhere(R,G,B);
}

/**
 * \brief restore default foreground and background colors
 */
static inline void GL_restore_default_colors() {
    printf(
        "\033[48;5;16m"   // set background color black
        "\033[38;5;15m"   // set foreground color white
    );
}

/**
 * \brief Call this function each time graphics should be cleared
 */
static inline void GL_clear() {
    GL_restore_default_colors();
    printf("\033[2J"); // clear screen
}

/**
 * \brief Moves current drawing position to top-left corner
 * \see GL_setpixelRGBhere() and GL_set2pixelsRGBhere()
 */
static inline void GL_home() {
    printf("\033[H");
}

/**
 * \brief Call this function before starting drawing graphics 
 *  or each time graphics should be cleared
 */
static inline void GL_init() {
    printf("\033[?25l"); // hide cursor
    GL_home();
    GL_clear();
}


/**
 * \brief Call this function at the end of the program
 */
static inline void GL_terminate() {
    GL_restore_default_colors();
    GL_gotoxy(0,GL_height);
    printf("\033[?25h"); // show cursor
}

/**
 * \brief Flushes pending graphic operations and waits a bit
 */
static inline void GL_swapbuffers() {
    // only flush if we are on a big machine, with true stdio support
    // otherwise does nothing (because our small MCU io lib is not buffered)
#ifdef BIGCPU    
   fflush(stdout);
#endif
#ifdef __linux__   
   usleep(1000000/GL_FPS);
#endif
}

typedef void (*GL_pixelfunc_RGB)(int x, int y, uint8_t* r, uint8_t* g, uint8_t* b);
typedef void (*GL_pixelfunc_RGBf)(int x, int y, float* r, float* g, float* b);

/**
 * \brief Draws an image by calling a user-specified function for each pixel.
 * \param[in] width , height dimension of the image in square pixels
 * \param[in] do_pixel the user function to be called for each pixel 
 *  (a "shader"), that determines the (integer) components r,g,b of 
 *   the pixel's color.
 * \details Uses half-charater pixels.
 */
static inline void GL_scan_RGB(
    int width, int height, GL_pixelfunc_RGB do_pixel
) {
    uint8_t r1, g1, b1;
    uint8_t r2, g2, b2;
    GL_home(); 
    for (int j = 0; j<height; j+=2) { 
	for (int i = 0; i<width; i++) {
	    do_pixel(i,j  , &r1, &g1, &b1);
	    do_pixel(i,j+1, &r2, &g2, &b2);
	    GL_set2pixelsRGBhere(r1,g1,b1,r2,g2,b2);
	    if(i == width-1) {
		GL_newline();
	    }
	}
    }
}

/**
 * brief Converts a floating point value to a byte.
 * \param[in] the floating point value in [0,1]
 * \return the byte, in [0,255]
 * \details the input value is clamped to [0,1]
 */ 
static inline uint8_t GL_ftoi(float f) {
    f = (f < 0.0f) ? 0.0f : f;
    f = (f > 1.0f) ? 1.0f : f;
    return (uint8_t)(255.0f * f);
}

/**
 * \brief Draws an image by calling a user-specified function for each pixel.
 * \param[in] width , height dimension of the image in square pixels
 * \param[in] do_pixel the user function to be called for each pixel 
 *  (a "shader"), that determines the (floating-point) components 
 *  fr,fg,fb of the pixel's color.
 * \details Uses half-charater pixels.
 */
static inline void GL_scan_RGBf(
    int width, int height, GL_pixelfunc_RGBf do_pixel
) {
    float fr1, fg1, fb1;
    float fr2, fg2, fb2;
    uint8_t r1, g1, b1;
    uint8_t r2, g2, b2;
    GL_home();
    for (int j = 0; j<height; j+=2) { 
	for (int i = 0; i<width; i++) {
	    do_pixel(i,j  , &fr1, &fg1, &fb1);
	    r1 = GL_ftoi(fr1);
	    g1 = GL_ftoi(fg1);
	    b1 = GL_ftoi(fb1);	    
	    do_pixel(i,j+1, &fr2, &fg2, &fb2);
	    r2 = GL_ftoi(fr2);
	    g2 = GL_ftoi(fg2);
	    b2 = GL_ftoi(fb2);	    
	    GL_set2pixelsRGBhere(r1,g1,b1,r2,g2,b2);
	    if(i == width-1) {
		GL_newline();
	    }
	}
    }
}

/***************************************************************/

#define INSIDE 0
#define LEFT   1
#define RIGHT  2
#define BOTTOM 4
#define TOP    8

#define XMIN 0
#define XMAX (GL_width-1)
#define YMIN 0
#define YMAX (GL_height-1)

#define code(x,y) \
    ((x) < XMIN) | (((x) > XMAX)<<1) | (((y) < YMIN)<<2) | (((y) > YMAX)<<3) 

/***************************************************************/

static inline void GL_line(
    int x1, int y1, int x2, int y2, int R, int G, int B
) {
    int x,y,dx,dy,sx,sy,tmp;

    /* Cohen-Sutherland line clipping. */
    int code1 = code(x1,y1);
    int code2 = code(x2,y2);
    int codeout;

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
    
    // Swap both extremities to ensure x increases
    if(x2 < x1) {
       tmp = x2;
       x2 = x1;
       x1 = tmp;
       tmp = y2;
       y2 = y1;
       y1 = tmp;
    }
   
    // Bresenham line drawing.
    dy = y2 - y1;
    sy = 1;
    if(dy < 0) {
	sy = -1;
	dy = -dy;
    }

    dx = x2 - x1;
   
    x = x1;
    y = y1;
    
    if(dy > dx) {
	int ex = (dx << 1) - dy;
	for(int u=0; u<dy; u++) {
	    GL_setpixelRGB(x,y,R,G,B);
	    y += sy;
	    if(ex >= 0)  {
		x++;
		ex -= dy << 1;
		GL_setpixelRGB(x,y,R,G,B);
	    }
	    while(ex >= 0)  {
		x++;
		ex -= dy << 1;
	        putchar(' ');
	    }
	    ex += dx << 1;
	}
    } else {
	int ey = (dy << 1) - dx;
	for(int u=0; u<dx; u++) {
	    GL_setpixelRGB(x,y,R,G,B);
	    x++;
	    while(ey >= 0) {
		y += sy;
		ey -= dx << 1;
		GL_setpixelRGB(x,y,R,G,B);
	    }
	    ey += dy << 1;
	}
    }
}


/***************************************************************/

#ifdef GL_USE_TURTLE

#include "sintab.h" // Ugly !!!

typedef struct {
    int x;        // in [0..79]
    int y;        // in [0..24]
    int angle;    // in degrees
    int R,G,B;    // pen color
    int pendown;  // draw if non-zero
} Turtle;
    
static inline void Turtle_init(Turtle* T) {
    T->x = GL_width/2;
    T->y = GL_height/2;
    T->angle = -90;
    T->pendown = 1;
    T->R = 255;
    T->G = 255;
    T->B = 255;
}

static inline void Turtle_pen_up(Turtle* T) {
    T->pendown = 0;
}

static inline void Turtle_pen_down(Turtle* T) {
    T->pendown = 1;
}

static inline void Turtle_pen_color(Turtle* T, int R, int G, int B) {
    T->R = R;
    T->G = G;
    T->B = B;
}

static inline void Turtle_forward(Turtle* T, int distance) {
    int last_x = T->x;
    int last_y = T->y;
    int a = T->angle;
    while(a < 0) {
        a += 360;
    }
    while(a > 360) {
        a -= 360;
    }
    T->x += (costab[a] * distance) / 256;
    T->y += (sintab[a] * distance) / 256;
    if(T->pendown) {
        GL_line(last_x, last_y, T->x, T->y, T->R, T->G, T->B);
    }
}

static inline void Turtle_backward(Turtle* T, int distance) {
    Turtle_forward(T,-distance);
}

static inline void Turtle_turn_right(Turtle* T, int delta_angle) {
    T->angle += delta_angle;
}

static inline void Turtle_turn_left(Turtle* T, int delta_angle) {
    Turtle_turn_right(T, -delta_angle);
}

#endif
