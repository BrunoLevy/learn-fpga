#include <femtoGL.h>

int      FGA_mode = -1;
uint16_t FGA_width;
uint16_t FGA_height;

static void FGA_setmode_internal(int width, int height, int colormode, int displaymode) {
  FGA_SET_REG(FGA_REG_RESOLUTION, width | (height << 12));
  FGA_SET_REG(FGA_REG_COLORMODE, colormode);
  FGA_SET_REG(FGA_REG_DISPLAYMODE, displaymode);
  FGA_SET_REG(FGA_REG_ORIGIN, 0);
  FGA_SET_REG(FGA_REG_WRAP, width*height);
  FGA_width  = width;
  FGA_height = height;
}

void FGA_setmode(int mode) {
   if(!FEMTOSOC_HAS_DEVICE(IO_FGA_CNTL_bit)) {
      return;
   }
   FGA_mode = mode;
   mode = MAX(mode,0); // mode -1 = OLED, emulate with mode 0
   memset(FGA_BASEMEM,0,128000);
   switch(mode) {
   case FGA_MODE_320x200x16bpp:
     FGA_setmode_internal(320, 200, FGA_MODE_16bpp, FGA_MAGNIFY);
     break;
   case FGA_MODE_320x200x8bpp:
     FGA_setmode_internal(
	 320, 200, FGA_MODE_8bpp | FGA_COLORMAPPED, FGA_MAGNIFY
     );
     break;
   case FGA_MODE_640x400x4bpp:
     FGA_setmode_internal(640,400,FGA_MODE_4bpp|FGA_COLORMAPPED,0);
     break;
   case FGA_MODE_800x600x2bpp:
     FGA_setmode_internal(800,600,FGA_MODE_2bpp|FGA_COLORMAPPED,0);
     break;
   case FGA_MODE_1024x768x1bpp:
     FGA_setmode_internal(1024,768,FGA_MODE_1bpp|FGA_COLORMAPPED,0);
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
  FGA_CMD2(FGA_CMD_SET_WWINDOW_X, x1, x2);
  FGA_CMD2(FGA_CMD_SET_WWINDOW_Y, y1, y2);  
}

int FGA_bpp() {
   switch(FGA_mode) {
    case  GL_MODE_OLED:            return 16;
    case  FGA_MODE_320x200x16bpp:  return 16;
    case  FGA_MODE_320x200x8bpp:   return 8;
    case  FGA_MODE_640x400x4bpp:   return 4;
    case  FGA_MODE_800x600x2bpp:   return 2;
    case  FGA_MODE_1024x768x1bpp:  return 1;      
   }
   return 0;
}


/***************************************************************************/

