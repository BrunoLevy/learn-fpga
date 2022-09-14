#ifndef TTY_GRAPHICS_H
#define TTY_GRAPHICS_H

#include <stdio.h>
#include <stdint.h>

/**
 * \brief Resets default tty colors (white foreground, black background)
 * \details It is useful to call this function once all graphics are finished,
 *    else text output might be invisible or difficult to see depending on
 *    current foreground and background colors.
 */
static inline void tty_graphics_reset_colors() {
    printf("\033[48;5;16m"   // set background color black
	   "\033[38;5;15m"   // set foreground color white
    );
}

/**
 * \brief Moves the cursor position to the origin (top left).
 */
static inline void tty_graphics_home() {
    printf("\033[H");
}

/**
 * \brief Clears the terminal.
 */
static inline void tty_graphics_clear() {
    printf("\033[2J");
}

/**
 * \brief Initializes "graphics mode".
 * \details resets default colors, clears the terminal and moves the 
 *  cursor to the top-left position.
 */
static inline void tty_graphics_init() {
    tty_graphics_reset_colors();
    tty_graphics_home();
    tty_graphics_clear();
}

/**
 * \brief Terminates "graphics mode".
 * \details Restores default foreground and background colors.
 */
static inline void tty_graphics_terminate() {
    tty_graphics_reset_colors();
}

/**
 * \brief Moves the cursor to a specific location.
 */
static inline void tty_graphics_gotoXY(int x, int y) {
    printf("\033[%d;%dH",y,x); 
}

/**
 * \brief Draws a "pixel" (a block) at the current
 *  cursor position and advances the current cursor
 *  position.
 */
static inline void tty_graphics_draw_one_pixel(
    uint8_t r, uint8_t g, uint8_t b
) {
    printf("\033[48;2;%d;%d;%dm ",(int)r,(int)g,(int)b);    
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
static inline void tty_graphics_draw_two_pixels(
    uint8_t r1, uint8_t g1, uint8_t b1,
    uint8_t r2, uint8_t g2, uint8_t b2
) {
    if((r2 == r1) && (g2 == g1) && (b2 == b1)) {
	tty_graphics_draw_one_pixel(r1,g1,b1);
    } else {
	printf("\033[48;2;%d;%d;%dm",(int)r1,(int)g1,(int)b1);	   	   
	printf("\033[38;2;%d;%d;%dm",(int)r2,(int)g2,(int)b2);
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
static inline void tty_graphics_newline() {
    printf("\033[38;2;0;0;0m");	   
    printf("\033[48;2;0;0;0m\n");
}

typedef void (*tty_graphics_pixelfunc)(int x, int y, uint8_t* r, uint8_t* g, uint8_t* b);
typedef void (*tty_graphics_fpixelfunc)(int x, int y, float* r, float* g, float* b);

/**
 * \brief Draws an image by calling a user-specified function for each pixel.
 * \param[in] width , height dimension of the image in square pixels
 * \param[in] do_pixel the user function to be called for each pixel (a "shader"), that
 *  determines the (integer) components r,g,b of the pixel's color.
 * \details Uses half-charater pixels.
 */
static inline void tty_graphics_scan(int width, int height, tty_graphics_pixelfunc do_pixel) {
    uint8_t r1, g1, b1;
    uint8_t r2, g2, b2;
    tty_graphics_home();
    for (int j = 0; j<height; j+=2) { 
	for (int i = 0; i<width; i++) {
	    do_pixel(i,j  , &r1, &g1, &b1);
	    do_pixel(i,j+1, &r2, &g2, &b2);
	    tty_graphics_draw_two_pixels(r1,g1,b1,r2,g2,b2);
	    if(i == width-1) {
		tty_graphics_newline();
	    }
	}
    }
}

static inline uint8_t tty_graphics_ftoi(float f) {
    f = (f < 0.0f) ? 0.0f : f;
    f = (f > 1.0f) ? 1.0f : f;
    return (uint8_t)(255.0f * f);
}

/**
 * \brief Draws an image by calling a user-specified function for each pixel.
 * \param[in] width , height dimension of the image in square pixels
 * \param[in] do_pixel the user function to be called for each pixel (a "shader"), that
 *  determines the (floating-point) components fr,fg,fb of the pixel's color.
 * \details Uses half-charater pixels.
 */
static inline void tty_graphics_fscan(int width, int height, tty_graphics_fpixelfunc do_pixel) {
    float fr1, fg1, fb1;
    float fr2, fg2, fb2;
    uint8_t r1, g1, b1;
    uint8_t r2, g2, b2;
    tty_graphics_home();
    for (int j = 0; j<height; j+=2) { 
	for (int i = 0; i<width; i++) {
	    do_pixel(i,j  , &fr1, &fg1, &fb1);
	    r1 = tty_graphics_ftoi(fr1);
	    g1 = tty_graphics_ftoi(fg1);
	    b1 = tty_graphics_ftoi(fb1);	    
	    do_pixel(i,j+1, &fr2, &fg2, &fb2);
	    r2 = tty_graphics_ftoi(fr2);
	    g2 = tty_graphics_ftoi(fg2);
	    b2 = tty_graphics_ftoi(fb2);	    
	    tty_graphics_draw_two_pixels(r1,g1,b1,r2,g2,b2);
	    if(i == width-1) {
		tty_graphics_newline();
	    }
	}
    }
}

#endif
