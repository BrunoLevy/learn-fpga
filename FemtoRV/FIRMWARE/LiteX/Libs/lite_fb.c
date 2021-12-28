#include "lite_fb.h"
#include <string.h>

#ifdef CSR_VIDEO_FRAMEBUFFER_BASE

void fb_on(void) {
   video_framebuffer_vtg_enable_write(1);
   video_framebuffer_dma_enable_write(1);
}

void fb_off(void) {
   video_framebuffer_vtg_enable_write(0);
   video_framebuffer_dma_enable_write(0);
}


int fb_init(void) {
   fb_off();
   fb_clear();
   fb_on();
   return 1;
}

void fb_clear(void) {
   memset((void*)FB_BASE, 0, FB_WIDTH*FB_HEIGHT*4);
}

#else

int      fb_init(void) { return 0; }
void     fb_on(void) {}
void     fb_off(void) {}
void     fb_clear(void) {}

#endif
