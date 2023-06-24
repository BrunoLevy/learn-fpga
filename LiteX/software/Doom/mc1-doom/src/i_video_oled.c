//-----------------------------------------------------------------------------
//
//      DOOM graphics renderer for OLED display on LiteX LiteOS
//               (not part of mc1-doom)
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

/*
   320x200 -> OLED_WIDTH x OLED_HEIGHT:
   framebuffer pointer increment for next pixel
*/
static uint8_t oled_map_dx[OLED_WIDTH]   __attribute((section(".fastdata")));

/*
    320x200 -> OLED_WIDTH x OLED_HEIGHT:
    framebuffer pointer increment for next line divided by 8 (shifted >> 3)
*/
static uint8_t oled_map_dy[OLED_HEIGHT]  __attribute((section(".fastdata")));

static inline int map(int x, int in_max, int out_max) {
    return x * in_max / out_max;
}

static inline int map_delta(int x, int in_max, int out_max) {
    if(x == 0) {
        return 0;
    }
    return map(x, in_max, out_max) - map(x-1, in_max, out_max);
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
   for(int x=0; x<OLED_WIDTH; ++x) {
      oled_map_dx[x] = (uint8_t)(map_delta(x, 320, OLED_WIDTH));
   }
   for(int y=0; y<OLED_HEIGHT; ++y) {
      oled_map_dy[y] = (uint8_t)((map_delta(y, 200, OLED_HEIGHT)*320)>>3);
   }
   
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


//------------------------

#ifdef CSR_OLED_SPI_BASE    

// Wait for SPI driver to have finished sending data
static inline void oled_wait(void) {
   while(oled_spi_status_read() != OLED_SPI_DONE);
}

// Same as in lite_oled, but does not change CS and CMD/DAT
// and does not wait for SPI to have finished sending data
static inline void oled_byte_raw(uint8_t b) {
   oled_spi_mosi_write(b);
   oled_spi_control_write(8*OLED_SPI_LENGTH | OLED_SPI_START);
}

// Same as in lite_oled, but does not change CS and CMD/DAT
// and does not wait for SPI to have finished sending data
static inline void oled_data_uint16_raw(uint16_t RGB) {
   // Unfortunately, in LiteX, the SPI driver can only send
   // 8 bits at a time (the shifter is only 8 bits wide)
   oled_byte_raw((uint8_t)(RGB>>8));
   oled_wait();
   oled_byte_raw((uint8_t)(RGB));
}

#endif

//------------------------

void I_FinishUpdate (void) {

#ifdef CSR_OLED_SPI_BASE    
    const unsigned char* src = (const unsigned char*)screens[0];
    oled_write_window(0,0,OLED_WIDTH-1,OLED_HEIGHT-1);
    const unsigned char* line_ptr = src;

    // sending DATA to the SPI
    oled_ctl_out_write(OLED_SPI_DAT);
    // chip select ON (LOW)
    oled_spi_cs_write(OLED_SPI_CS_LOW);
    for(int y=0; y<OLED_HEIGHT; ++y) {
        const unsigned char* pixel_ptr = line_ptr;
        for(int x=0; x<OLED_WIDTH; ++x) {
            uint16_t pixelvalue = s_palette[*pixel_ptr];
	    // send pixel data to the SPI
            oled_data_uint16_raw(pixelvalue);
	    // increment framebuffer pointer 
            pixel_ptr += oled_map_dx[x];
	    // wait for SPI write dat to be finished
            oled_wait();
        }
        line_ptr += (oled_map_dy[y]<<3);
    }
    // chip select OFF (HIGH)
    oled_spi_cs_write(OLED_SPI_CS_HIGH);
#endif
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
