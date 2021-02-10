#include <femtoGL.h>

int      FGA_mode = -1;
uint16_t FGA_width;
uint16_t FGA_height;

void FGA_setmode(int mode) {
   if(!FEMTOSOC_HAS_DEVICE(IO_FGA_CNTL_bit)) {
      return;
   }
   FGA_mode = mode;
   mode = MAX(mode,0); // mode -1 = OLED, emulate with mode 0
   IO_OUT(IO_FGA_CNTL, FGA_SET_MODE | (mode << 8));
   memset(FGA_BASEMEM,0,128000);
   switch(mode) {
   case FGA_MODE_320x200x16bpp:
     FGA_width = 320;
     FGA_height = 200;
     break;
   case FGA_MODE_320x200x8bpp:
     FGA_width = 320;
     FGA_height = 200;
     break;
   case FGA_MODE_640x400x4bpp:
     FGA_width =  640;
     FGA_height = 400;
     break;
   }
   // Default palette: 0=black, all other colors=white
   // so that text will work.
   FGA_setpalette(0, 0, 0, 0);
   for(int i=1; i<255; ++i) {
      FGA_setpalette(i, 255, 255, 255);
   }
}

void FGA_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
  IO_OUT(IO_FGA_CNTL, FGA_SET_WWINDOW_X | x1 << 8 | x2 << 20);
  IO_OUT(IO_FGA_CNTL, FGA_SET_WWINDOW_Y | y1 << 8 | y2 << 20);  
}

/***************************************************************************/

