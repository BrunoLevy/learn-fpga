// This file is Copyright (c) 2021 Bruno Levy <Bruno.Levy@inria.fr>
//
// frame buffer

#ifndef LITE_FB
#define LITE_FB

#include <generated/csr.h>

#define FB_WIDTH  640
#define FB_HEIGHT 480

/** \brief base memory address of the framebuffer */
#define FB_BASE 0x40c00000

/**
 * \brief Initializes framebuffer
 * \details This also clears the framebuffer
 * \retval 1 on succes
 * \retval 0 on error
 */ 
int  fb_init(void);

/**
 * \brief Activates the framebuffer.
 * \details Does not clear framebuffer contents.
 */ 
void fb_on(void);

/**
 * \brief deactivates the framebuffer.
 * \details Framebuffer contents are maintained.
 */ 
void fb_off(void);

/**
 * \brief Sets a pixel, color specified as R,G,B components.
 * \param[in] x , y pixel coordinates, in [0..FB_WIDTH-1],[0..FB_HEIGHT-1]
 * \param[in] R , G , B color components, in [0..255]
 */ 
static inline void fb_setpixel_RGB(
    uint32_t x, uint32_t y, uint8_t R, uint8_t G, uint8_t B
) {
   uint32_t* pixel_base = ((uint32_t*)FB_BASE) + y * FB_WIDTH + x;
   // *pixel_base =  ((uint32_t)R << 8 | (uint32_t)G) << 8 | (uint32_t)B; // to be used with sdram-rate=1:1
   *pixel_base =  ((uint32_t)B << 8 | (uint32_t)G) << 8 | (uint32_t)R;    // to be used with sdram-rate=1:2
}


void fb_clear(void);

#endif
