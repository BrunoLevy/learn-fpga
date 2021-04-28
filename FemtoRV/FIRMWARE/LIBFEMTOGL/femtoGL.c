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

#ifdef FGA

static const char* modes[] = {
#ifdef SSD1351   
   "OLED 128x128 16",
#else
   "OLED 96x64   16",   
#endif   
   "FGA  320x200 16",
   "FGA  320x200 8",
   "FGA  640x400 4",
   "FGA  800x600 2",
   "FGA 1024x768 1",   
   NULL
};

static const char* RGB_modes[] = {
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
   if(mode == GL_MODE_CHOOSE) {
      mode = GUI_prompt("GFX MODE", modes) - 1;
   } else if(mode == GL_MODE_CHOOSE_RGB) {
      mode = GUI_prompt("GFX MODE", RGB_modes) - 1;
   }
   FGA_setmode(mode);     
   if(mode == -1) {
     oled_init();     
   } else {
     GL_width  = FGA_width;
     GL_height = FGA_height;
   }
}

#else

void GL_init(int mode) {
   GL_width  = OLED_WIDTH;
   GL_height = OLED_HEIGHT;
   oled_init();
}
#endif

void GL_clear() {
  GL_fill_rect(0,0,GL_width-1,GL_height-1,GL_bg);
}

void GL_wait_vbl() {
#ifdef FGA   
   if(FGA_mode != GL_MODE_OLED) {
      FGA_wait_vbl();
   }
#endif   
}

