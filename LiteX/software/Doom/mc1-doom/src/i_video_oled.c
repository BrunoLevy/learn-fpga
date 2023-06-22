// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
//      DOOM graphics renderer for OLED display on LiteX LiteOS
//
//-----------------------------------------------------------------------------

#include <lite_oled.h>
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
   if (initialized!=0)
     return;
   initialized = 1;
   screens[0] = (unsigned char*)malloc (SCREENWIDTH * SCREENHEIGHT);
    if (screens[0] == NULL)
        I_Error ("Couldn't allocate screen memory");
   oled_init();
}

void I_ShutdownGraphics (void) {
   free (screens[0]);
   oled_off();
}

void I_WaitVBL (int count) {
   
}

void I_StartFrame (void) {

}

void I_StartTic (void) {
}

void I_UpdateNoBlit (void) {

}

void I_FinishUpdate (void) {

    const unsigned char* src = (const unsigned char*)screens[0];
    float scaleX = (float)SCREENWIDTH / OLED_WIDTH;
    float scaleY = (float)SCREENHEIGHT / OLED_HEIGHT;
    for (uint8_t y = 0; y < OLED_HEIGHT; ++y) {
        int iy = (int)(y * scaleY);
        for(uint8_t x = 0; x < OLED_WIDTH; ++x){
                int ix = (int)(x * scaleX);
                uint32_t pixelvalue = s_palette[src[iy*SCREENWIDTH+ix]]; // nearest neighbor
                uint8_t pixel_a = (pixelvalue >> 24) & 0xFF;
                uint8_t pixel_b = (pixelvalue >> 16) & 0xFF;
                uint8_t pixel_g = (pixelvalue >> 8) & 0xFF;
                uint8_t pixel_r = (pixelvalue) & 0xFF;
                oled_setpixel_RGB(x, y, pixel_r, pixel_g, pixel_b);
        }
    }
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
