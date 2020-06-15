#include <femtorv32.h>

//#define FONT_8x8
#define FONT_5x6
//#define FONT_3x5

#if   defined(FONT_8x8)
#define FONT_WIDTH  8
#define FONT_HEIGHT 8
#elif defined(FONT_5x6)
#define FONT_WIDTH  6
#define FONT_HEIGHT 8
#elif defined(FONT_3x5)
#define FONT_WIDTH  4
#define FONT_HEIGHT 6
#endif

static int scrolling = 0;
static int cursor_X = 0;
static int cursor_Y = 0;
static int display_start_line = 0;

void GL_tty_init() {
    oled_init();
    oled_clear();
    set_putcharfunc(GL_putchar);
    cursor_X = 0;
    cursor_Y = 0;
    scrolling = 0;
    display_start_line = 0;
    oled1(0xA1, 0); /* reset display start line. */
}

void GL_tty_scroll() {
    /* Using SSD1351 'display start line' command, we 
       can scroll the terminal without memorizing the 
       contents anywhere !    
     */
    if(cursor_Y + FONT_HEIGHT > 128) {
       scrolling = 1;
       cursor_Y = 0;
    }
    if(!scrolling) {
	return;
    }
    oled_clear_rect(0,cursor_Y,127,cursor_Y+FONT_HEIGHT-1);
    oled1(0xA1, display_start_line + FONT_HEIGHT);
    display_start_line += FONT_HEIGHT;
    if(display_start_line > 127) {
       display_start_line = 0;
    }
}

int GL_putchar(int c) {
    if(c == '\n') {
	cursor_X = 0;
        cursor_Y += FONT_HEIGHT;
	GL_tty_scroll();
	return c;
    }
    GL_putchar_xy(cursor_X, cursor_Y, (char)c); 
    cursor_X += FONT_WIDTH;
    if(cursor_X > 127) {
	GL_putchar('\n');
    }
    return c;
}

void GL_putchar_xy(int X, int Y, char c) {
#if defined(FONT_8x8)   
   oled_write_window(X,Y,X+7,Y+7);   
   char* car_ptr = font_8x8 + (int)c * 8;
   for(int row=0; row<8; ++row) {
      for(int col=0; col<8; ++col) {
	 uint32_t BW = (car_ptr[col] & (1 << row)) ? 255 : 0;
	 IO_OUT(IO_OLED_DATA,BW);
	 oled_wait();
	 IO_OUT(IO_OLED_DATA,BW);
	 oled_wait();
      }
   }
#elif defined(FONT_5x6)
   oled_write_window(X,Y,X+5,Y+7);
   unsigned int chardata = ((unsigned int*)font_5x6)[c - ' '];
   int shifted = chardata & (1 << 30);
   for(int row=0; row<8; ++row) {
       for(int col=0; col<6; ++col) {
	   uint32_t BW;
	   if(col >= 5) {
	       BW = 0;
	   } else {
	       unsigned int coldata = (chardata >> (6 * col)) & 63;
	       if(shifted) {
		   coldata = coldata << 2;
	       }
	       BW = (coldata & (1 << row)) ? 255 : 0;
	   }
	   IO_OUT(IO_OLED_DATA,BW);
	   oled_wait();
	   IO_OUT(IO_OLED_DATA,BW);
	   oled_wait();
       }
   }
#elif defined(FONT_3x5)
   oled_write_window(X,Y,X+3,Y+5);
   uint16_t car_data = font_3x5[c - ' '];
   for(int row=0; row<6; ++row) {
      for(int col=0; col<4; ++col) {
	  uint32_t BW = 0;
	  if(col < 3) {
	      uint32_t coldata = (car_data >> (5 * col)) & 31;
	      BW = (coldata & (1 << row)) ? 255 : 0;
	  }
	 IO_OUT(IO_OLED_DATA,BW);
	 oled_wait();
	 IO_OUT(IO_OLED_DATA,BW);
	 oled_wait();
      }
   }
#endif
}
		
