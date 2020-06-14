#include <femtorv32.h>

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
       contents anywhere !                             */ 
    scrolling = scrolling || (cursor_Y >= 16);
    if(!scrolling) {
	return;
    }
    cursor_Y = cursor_Y & 15;
    /* clear line: todo, use fillrect when implemented */
    for(int x=0; x<16; ++x) {
	GL_putchar_xy(x*8, cursor_Y*8, ' ');
    }
    oled1(0xA1, display_start_line & 127);
    display_start_line += 8;
}

int GL_putchar(int c) {
    if(c == '\n') {
	cursor_X = 0;
	++cursor_Y;
	GL_tty_scroll();
	return c;
    }
    GL_putchar_xy(cursor_X*8, cursor_Y*8, (char)c);
    ++cursor_X;
    if(cursor_X >= 16) {
	GL_putchar('\n');
    }
    return c;
}

void GL_putchar_xy(int X, int Y, char c) {
   oled2(0x15,X,X+7); // column address
   oled2(0x75,Y,Y+7); // row address
   oled0(0x5c);       // write RAM
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
}

		
