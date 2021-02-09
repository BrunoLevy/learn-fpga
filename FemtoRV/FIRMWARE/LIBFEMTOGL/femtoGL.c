#include <femtoGL.h>

uint16_t GL_fg = 0xffff; 
uint16_t GL_bg = 0x0000;


void GL_set_fg(uint8_t r, uint8_t g, uint8_t b) {
    GL_fg = (uint16_t)GL_RGB((uint16_t)(r), (uint16_t)(g), (uint16_t)(b));
}

void GL_set_bg(uint8_t r, uint8_t g, uint8_t b) {
    GL_bg = (uint16_t)GL_RGB((uint16_t)(r), (uint16_t)(g), (uint16_t)(b));
}

extern uint16 GL_width  = 0;
extern uint16 GL_height = 0;

static char* modes[] = {
#ifdef SSD1351   
   "OLED 128x128 16",
#else
   "OLED 96x64   16",   
#endif   
   "FGA  320x200 16",
   "FGA  320x200 8",
   "FGA  640x400 4",
   NULL
};

static char* RGB_modes[] = {
#ifdef SSD1351   
   "OLED 128x128 16",
#else
   "OLED 96x64   16",   
#endif   
   "FGA  320x200 16",
   NULL
};

void GL_init(int mode) {
   GL_width  = OLED_WIDTH;
   GL_height = OLED_HEIGHT;
#ifdef FGA
   if(mode == GL_MODE_CHOOSE) {
      mode = GUI_prompt("GFX MODE", modes) - 1;
   } else if(mode == GL_MODE_CHOOSE_RGB) {
      mode = GUI_prompt("GFX MODE", RGB_modes) - 1;
   }
   FGA_setmode(mode);     
#else
   mode = -1;
#endif
   if(mode == -1) {
     oled_init();     
   } else {
     GL_width  = FGA_width;
     GL_height = FGA_height;
   }
}

void GL_fill_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
  if(FGA_mode == -1) {
    GL_write_window(x1,y1,x2,y2);
    for(int y=y1; y<=y2; ++y) {
      for(int x=x1; x<=x2; ++x) {
	GL_WRITE_DATA_UINT16(color);
      }
    }
  } else {
    FGA_fill_rect(x1,y1,x2,y2,color);
  }
}

void GL_clear() {
  GL_fill_rect(0,0,GL_width-1,GL_height-1,GL_bg);
}

		
