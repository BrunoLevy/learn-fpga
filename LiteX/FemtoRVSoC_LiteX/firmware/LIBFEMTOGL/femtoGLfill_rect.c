#include <femtoGL.h>

void GL_fill_rect(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint16_t color
) {
#ifdef FGA   
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
#else
    GL_write_window(x1,y1,x2,y2);
    for(int y=y1; y<=y2; ++y) {
      for(int x=x1; x<=x2; ++x) {
	GL_WRITE_DATA_UINT16(color);
      }
    }
#endif   
}
