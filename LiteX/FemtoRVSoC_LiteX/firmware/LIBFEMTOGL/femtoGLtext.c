#include <femtoGL.h>


/***********************************************************************/

static void font_func_8x16(int X, int Y, char c) {
   GL_write_window(X,Y,X+7,Y+15);   
   uint16_t* car_ptr = font_8x16 + (int)c * 8;
   for(int row=0; row<16; ++row) {
      for(int col=0; col<8; ++col) {
	 uint32_t BW = (car_ptr[col] & (1 << row)) ? 255 : 0;
	 GL_WRITE_DATA_UINT16(BW ? GL_fg : GL_bg);
      }
   }
}

const GLFont Font8x16 = {
   font_func_8x16,
   8,16
};

static void font_func_8x8(int X, int Y, char c) {
   GL_write_window(X,Y,X+7,Y+7);   
   uint8_t* car_ptr = font_8x8 + (int)c * 8;
   for(int row=0; row<8; ++row) {
      for(int col=0; col<8; ++col) {
	 uint32_t BW = (car_ptr[col] & (1 << row)) ? 255 : 0;
	 GL_WRITE_DATA_UINT16(BW ? GL_fg : GL_bg);
      }
   }
}

const GLFont Font8x8 = {
   font_func_8x8,
   8,8
};

static void font_func_5x6(int X, int Y, char c) {
   GL_write_window(X,Y,X+5,Y+7);
   uint32_t chardata = font_5x6[c - ' '];
   // bit 30 indicates whether character needs to be shifted downwards by
   // two pixels (for instance, for letters 'p','q','g')
   int shifted = chardata & (1 << 30);
   for(int row=0; row<8; ++row) {
       for(int col=0; col<6; ++col) {
	   uint32_t BW = 0;
	   if(col < 5) {
	       unsigned int coldata = (chardata >> (6 * col)) & 63;
	       if(shifted) {
		   coldata = coldata << 2;
	       }
	       BW = (coldata & (1 << row)) ? 255 : 0;
	   }
	   GL_WRITE_DATA_UINT16(BW ? GL_fg : GL_bg);
       }
   }
}

const GLFont Font5x6 = {
   font_func_5x6,
   6,8 /* yes, 6x8 for 5x6, some chars have legs */
};

static void font_func_3x5(int X, int Y, char c) {
   // In the pico8 font, small caps and big caps
   // are swapped (I don't know why). TODO: fix
   // the data instead, will be cleaner...
   if(c >= 'A' && c <= 'Z') {
      c = c - 'A' + 'a';
   } else if(c >= 'a' && c <= 'z') {
      c = c - 'a' + 'A';
   }
   GL_write_window(X,Y,X+3,Y+5);
   uint16_t car_data = font_3x5[c - ' '];
   for(int row=0; row<6; ++row) {
      for(int col=0; col<4; ++col) {
	  uint32_t BW = 0;
	  if(col < 3) {
	      uint32_t coldata = (car_data >> (5 * col)) & 31;
	      BW = (coldata & (1 << row)) ? 255 : 0;
	  }
          GL_WRITE_DATA_UINT16(BW ? GL_fg : GL_bg);	 
      }
   }
}

const GLFont Font3x5 = {
   font_func_3x5,
   4,6 /* yes, 4x6 for 3x5, additional space. */
};

GLFont* GL_current_font = &Font5x6;

void GL_set_font(GLFont* font) {
   GL_current_font = font;
}

/*****************************************************************************/

static int scrolling = 0; 
static int cursor_X = 0;
static int cursor_Y = 0;
static int display_start_line = 0;
static int last_char_was_CR = 0;

void GL_tty_init(int mode) {
    GL_init(mode);
    GL_clear();
    set_putcharfunc(GL_putchar);
    cursor_X = 0;
    cursor_Y = 0;
    scrolling = 0;
    display_start_line = 0;
    oled1(0xA1, 0); /* reset display start line. */
    FGA_SET_REG(FGA_REG_ORIGIN, 0);
    GL_set_font(&Font5x6);
}

void GL_tty_goto_xy(int X, int Y) {
    cursor_X = X;
    cursor_Y = Y;
}

/* 
 Using SSD1351 'display start line' command, we 
 can scroll the terminal without memorizing the 
 contents anywhere !    
 */
void GL_tty_scroll() {
    if(cursor_Y >= GL_height) {
       scrolling = 1;
       cursor_Y = 0;
    }
    if(!scrolling) {
	return;
    }
    GL_fill_rect(
	 0,cursor_Y,GL_width-1,cursor_Y+GL_current_font->height-1, GL_bg
    );
    display_start_line += GL_current_font->height;
    if(display_start_line >= GL_height) {
       display_start_line = 0;
    }
    oled1(0xA1, display_start_line);
    FGA_SET_REG(FGA_REG_ORIGIN, (display_start_line * FGA_width));
}

int GL_putchar(int c) {

   if(last_char_was_CR) {
      GL_tty_scroll();
      last_char_was_CR = 0;
   }
   
   if(c == '\r') {
      if(cursor_X >= GL_current_font->width) {
	 cursor_X -= GL_current_font->width;
      }
      return c;
   }
    
   if(c == '\n') {
      last_char_was_CR = 1; 
      cursor_X = 0;
      cursor_Y += GL_current_font->height;
      return c;
   }
   
   GL_putchar_xy(cursor_X, cursor_Y, (char)c); 
   cursor_X += GL_current_font->width;
   if(cursor_X >= GL_width) {
      GL_putchar('\n');
   }
   return c;
}

void GL_putchar_xy(int X, int Y, char c) {
   GL_current_font->func(X,Y,c);
}
		
