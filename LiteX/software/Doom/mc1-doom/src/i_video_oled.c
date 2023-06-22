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

static uint16_t s_palette[256] __attribute((section(".fastdata")));

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
    oled_write_window(8,7,87,56);
    const unsigned char* line_ptr = src;
    for(int y=0; y<200; y+=4) {
        for(int x=0; x<320; x+=4) {
            uint16_t pixelvalue = s_palette[line_ptr[x]];
            oled_data_uint16(pixelvalue);
        }
        line_ptr += 4*320;
    }
    /*
    float scaleX = (float)SCREENWIDTH / OLED_WIDTH;
    float scaleY = (float)SCREENHEIGHT / OLED_HEIGHT;
    for (uint8_t y = 0; y < OLED_HEIGHT; ++y) {
        int iy = (int)(y * scaleY);
        for(uint8_t x = 0; x < OLED_WIDTH; ++x){
            int ix = (int)(x * scaleX);
            uint16_t pixelvalue = s_palette[src[iy*SCREENWIDTH+ix]];
            oled_setpixel_uint16(x, y, pixelvalue);
        }
    }
    */
}

void I_ReadScreen (byte* scr) {
    memcpy (scr, screens[0], SCREENWIDTH * SCREENHEIGHT);
}

void I_SetPalette (byte* palette) {
    for (int i = 0; i < 256; ++i) {
        uint16_t r = (uint16_t)gammatable[usegamma][*palette++];
        uint16_t g = (uint16_t)gammatable[usegamma][*palette++];
        uint16_t b = (uint16_t)gammatable[usegamma][*palette++];
        s_palette[i] = oled_RGB_to_uint16(r,g,b);
    }
}
