//-----------------------------------------------------------------------------
//
//      DOOM graphics renderer for LiteX framebuffer
//           (not part of mc1-doom)
//
//-----------------------------------------------------------------------------

#include <lite_fb.h>
#include <stdlib.h>

#include "doomdef.h"
#include "doomstat.h"
#include "d_main.h"
#include "i_system.h"
#include "m_argv.h"
#include "v_video.h"


static uint32_t s_palette[256] __attribute((section(".fastdata")));

static inline uint32_t color_to_argb8888 (
   unsigned int r,
   unsigned int g,
   unsigned int b
) {
   return 0xff000000u | (b << 16) | (g << 8) | r;
}


void I_InitGraphics (void) {
   // Only initialize once.
   static int initialized = 0;
   if (initialized)
     return;
   initialized = 1;
   
   fb_init();
   fb_set_dual_buffering(1);
}

void I_ShutdownGraphics (void) {
   free (screens[0]);
   fb_off();
}

void I_WaitVBL (int count) {
   
}

void I_StartFrame (void) {
   // er?
}

void I_StartTic (void) {
}

void I_UpdateNoBlit (void) {
    // what is this?
}

void I_FinishUpdate (void) {
    // Copy the internal screen to the framebuffer,
    // 8-bit indexed pixels to 32-bit ARGB.

    // "no conversion" blitting, for testing speed
    /*
    const uint32_t* src = (const uint32_t*)screens[0];
    uint32_t* row_dst = fb_base;
    for (int y = 0; y < SCREENHEIGHT; ++y)     {
	uint32_t* dst = row_dst;
        for (int x = 0; x < SCREENWIDTH/4; ++x) {
	    *dst++ =*src++;
	}
	row_dst += FB_WIDTH;
    }
    */


    const unsigned char* row_src = (const unsigned char*)screens[0];
    const unsigned char* row_src_end = row_src + SCREENWIDTH;
   
    uint32_t* row_dst = fb_base + (FB_WIDTH-SCREENWIDTH)/2 +
                                  (FB_HEIGHT-SCREENHEIGHT)*FB_WIDTH/2;    
   
    for (int y = 0; y < SCREENHEIGHT; ++y) {
       uint32_t* dst = row_dst;
       for(const unsigned char* src = row_src; src < row_src_end; src++,dst++) {
	  *dst = s_palette[*src];
       }
       row_src = row_src_end;
       row_src_end += SCREENWIDTH;
       row_dst += FB_WIDTH;
    }
   
   
    fb_swap_buffers();
}

void I_ReadScreen (byte* scr) {
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}

void I_SetPalette (byte* palette) {
    for (int i = 0; i < 256; ++i) {
        unsigned int r = (unsigned int)gammatable[usegamma][*palette++];
        unsigned int g = (unsigned int)gammatable[usegamma][*palette++];
        unsigned int b = (unsigned int)gammatable[usegamma][*palette++];
        s_palette[i] = color_to_argb8888 (r, g, b);
    }
}
