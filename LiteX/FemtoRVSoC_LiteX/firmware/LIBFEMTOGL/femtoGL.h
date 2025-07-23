#ifndef H__FEMTOGL__H
#define H__FEMTOGL__H

#include <femtorv32.h>
#include <FGA.h>

/* Font maps */
extern uint16_t* font_8x16;   /*  8 half-words per char. Each half-word corresponds to a column.   */
extern uint8_t*  font_8x8;    /*  8 bytes per char. Each byte corresponds to a column.   */
extern uint32_t* font_5x6;    /*  4 bytes per char. 5 columns of 6 bits. bit 31=shift.   */
extern uint16_t* font_3x5;    /*  2 bytes per char. 3 columns of 5 bits.                 */

/* Converts three R,G,B components (between 0 and 255) into a 16 bits color value for the OLED screen or FGA. */
#define GL_RGB(R,G,B) ((((((R) & 0xF8) << 5) | ((G) & 0xF8)) << 3) | ((B) >> 3))

extern uint16_t GL_width;
extern uint16_t GL_height;

extern uint16_t GL_fg;
extern uint16_t GL_bg;

extern void GL_set_fg(uint8_t r, uint8_t g, uint8_t b);
extern void GL_set_bg(uint8_t r, uint8_t g, uint8_t b);

#define GL_MODE_CHOOSE_RGB -3
#define GL_MODE_CHOOSE     -2
#define GL_MODE_OLED       -1

void GL_init(int mode);
void GL_clear();
void GL_wait_vbl();

void GL_fill_rect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color) RV32_FASTCODE;
void GL_setpixel(int x, int y, uint16_t color) RV32_FASTCODE;
void GL_line(int x1, int y1, int x2, int y3, uint16_t color) RV32_FASTCODE;
void GL_fill_poly(int nb_pts, int* points, uint16_t color) RV32_FASTCODE;


extern int      FGA_mode;
extern uint16_t FGA_width;
extern uint16_t FGA_height;
extern int      FGA_bpp();

extern void FGA_wait_vbl();
extern void FGA_clear();
extern void FGA_setpixel(int x, int y, uint16_t color);
extern void FGA_line(int x1, int y1, int x2, int y3, uint16_t color);
extern void FGA_fill_rect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color);
extern void FGA_fill_poly(int nb_pts, int* points, uint16_t color);

#define GL_POLY_LINES 1
#define GL_POLY_FILL  2
extern int gl_polygon_mode;
#define GL_polygon_mode(mode) gl_polygon_mode = (mode);

#define GL_FRONT_FACE     1
#define GL_BACK_FACE      2
#define GL_FRONT_AND_BACK 3
extern int gl_culling_mode;
#define GL_culling_mode(mode) gl_culling_mode = (mode);

void femtosoc_tty_init();     /* Initializes tty (putchar()) based on present devices.
			       * Note: pulls all fonts (eats up a consequent part of the
			       * available 6Kb... Do not use systematically.
			       */
void MAX7219_tty_init();      /* Initializes led matrix and redirects output to it.     */


typedef void (*GLFontFunc)(int x, int y, char c);
typedef struct {
   GLFontFunc func;
   uint8_t width;
   uint8_t height;
} GLFont;

extern const GLFont Font8x16;
extern const GLFont Font8x8;
extern const GLFont Font5x6;
extern const GLFont Font3x5;

extern GLFont* GL_current_font;

void GL_set_font(GLFont* font);
void GL_tty_init(int mode); /* Initializes OLED screen and redirects output to it.    */
void GL_tty_goto_xy(int X, int Y);
int  GL_putchar(int c);
void GL_putchar_xy(int x, int y, char c);

void FGA_setmode(int mode);

/* 
 * Femto Graphics Adapter 
 * 
 * Mode 0:
 * Flat 320x200x16bpp buffer, write-only 
 * Color encoding same as SSD1351 (use GL_RGB() to encode colors)
 */
#define FGA_BASEMEM (void*)(1 << 21)

static inline void FGA_setpalette(int index, uint8_t R, uint8_t G, uint8_t B) {
  FGA_CMD2(FGA_CMD_SET_PALETTE_R, index, R);
  FGA_CMD2(FGA_CMD_SET_PALETTE_G, index, G);
  FGA_CMD2(FGA_CMD_SET_PALETTE_B, index, B);  
}

/* Simple "GUI" functions */
int GUI_prompt(char* title, char** options);

/* Low-level */

/* Converts three R,G,B components (between 0 and 255) into a 16 bits color value for the OLED screen or FGA. */
#define GL_RGB(R,G,B) ((((((R) & 0xF8) << 5) | ((G) & 0xF8)) << 3) | ((B) >> 3))

/*
 * The magic of 1-hot encoding for memory-mapped hw registers: one can
 * write in two register simultaneously by setting both bits in the address.
 * Here we send the same graphic byte to the OLED display and FGA graphic board,
 * so that graphic programs work on both, with mirrored display.
 */ 

#define IO_GFX_DAT (IO_SSD1351_DAT16 | IO_FGA_DAT) 
#define GL_WRITE_DATA_UINT16(RGB) IO_OUT(IO_GFX_DAT,(RGB))
#define GL_WRITE_DATA_RGB(R,G,B)  GL_WRITE_DATA_UINT16(GL_RGB(R,G,B))

void FGA_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2);

#ifdef FGA
static inline void GL_write_window(int x1, int y1, int x2, int y2) {
# if defined(SSD1351) || defined(SSD1331)
   if(FGA_mode == -1) {
      oled_write_window(x1,y1,x2,y2);
   }
# endif
   FGA_write_window(x1,y1,x2,y2);   
}
#else
static inline void GL_write_window(int x1, int y1, int x2, int y2) {
   oled_write_window(x1,y1,x2,y2);
}
#endif

#endif
