// This file is Copyright (c) 2021 Bruno Levy <Bruno.Levy@inria.fr>
//
// Tiny graphics library for the LiteX frame buffer

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
 * \brief Encodes a pixel given its R,G,B components.
 * \param[in] R , G , B color components, in [0..255]
 * \retval pixel value.
 */ 
static inline uint32_t fb_RGB(uint8_t R, uint8_t G, uint8_t B) {
   // return  ((uint32_t)R << 8 | (uint32_t)G) << 8 | (uint32_t)B; // to be used with sdram-rate=1:1
   return ((uint32_t)B << 8 | (uint32_t)G) << 8 | (uint32_t)R;    // to be used with sdram-rate=1:2
}

/**
 * \brief Gets a pixel address from its coordinates.
 * \param[in] x , y pixel coordinates, in [0..FB_WIDTH-1],[0..FB_HEIGHT-1]
 * \return the address of the pixel in the framebuffer.
 */ 
static inline uint32_t* fb_pixel_address(uint32_t x, uint32_t y) {
   return ((uint32_t*)FB_BASE) + y * FB_WIDTH + x;
}

/**
 * \brief Sets a pixel, color specified as pixel value.
 * \details No clipping, no verification of coordinates !
 * \param[in] x , y pixel coordinates, in [0..FB_WIDTH-1],[0..FB_HEIGHT-1]
 * \param[in] RGB pixel value
 * \see fb_setpixel_RGB(), fb_RGB()
 */ 
static inline void fb_setpixel(
    uint32_t x, uint32_t y, uint32_t RGB
) {
   *fb_pixel_address(x,y) = RGB;
}

/**
 * \brief Sets a pixel, color specified as R,G,B components.
 * \details No clipping, no verification of coordinates !
 * \param[in] x , y pixel coordinates, in [0..FB_WIDTH-1],[0..FB_HEIGHT-1]
 * \param[in] R , G , B color components, in [0..255]
 */ 
static inline void fb_setpixel_RGB(
    uint32_t x, uint32_t y, uint8_t R, uint8_t G, uint8_t B
) {
   fb_setpixel(x,y,fb_RGB(R,G,B));
}

/**
 * \brief Clears the screen.
 */ 
void fb_clear(void);

/**
 * \brief Sets the clipping rectangle.
 * \param[in] x1 , y1 , x2 , y2 the coordinates of the lower-left and
 *   upper-right corners of the clipping rectangle, 
 *   in 0..FB_WIDTH-1 , 0..FB_HEIGHT-1.
 */  
void fb_set_cliprect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2);

/**
 * \brief Fills a rectangle with a specified color.
 * \details No clipping, no verification of coordinates !
 * \param[in] x1 , y1 , x2 , y2 coordinates of the lower-left and upper-right
 *   corners of the rectangle, in 0..FB_WIDTH-1 , 0..FB_HEIGHT-1
 * \param[in] RGB pixel color
 * \see fb_RGB()
 */ 
void fb_fillrect(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2, uint32_t RGB);

/**
 * \brief Draws a line with a specified color.
 * \param[in] x1 , y1 , x2 , y2 coordinates of the extremities of the line.
 *   they are clipped to 0..FB_WIDTH-1 , 0..FB_HEIGHT-1
 * \param[in] RGB pixel color
 * \see fb_RGB()
 */ 
void fb_line(int x1, int y1, int x2, int y2, uint32_t RGB);


/**
 * \brief Polygon mode constants.
 * \see fb_set_poly_mode()
 */
typedef enum {FB_POLY_LINES=0, FB_POLY_FILL=1} PolyMode;

/**
 * \brief Sets polygon mode.
 * \param[in] mode one of:
 *   - FB_POLY_LINES (draw polygon outlines), 
 *   - FB_POLY_FILL (filled polygons, default)
 */
void fb_set_poly_mode(PolyMode mode);

/**
 * \brief Polygon culling constants.
 * \see fb_set_poly_culling()
 */
typedef enum {FB_POLY_CW=1, FB_POLY_CCW=2, FB_POLY_NO_CULLING=3} PolyCulling;

/**
 * \brief Sets polygon culling mode.
 * \param[in] culling one of:
 *  - FB_POLY_CW: draw clockwise polygons only.
 *  - FB_POLY_CCW: draw counterclockwise polygons only.
 *  - FB_POLY_NO_CULLING: always draw polygons (default).
 */
void fb_set_poly_culling(PolyCulling culling);


/**
 * \brief Fills a polygon with a specified color.
 * \param[in] nb_pts number of points of the polygon.
 * \param[in] points a pointer to the 2*\p nb_points coordinates of the points. 
 *   They are clipped to 0..FB_WIDTH-1 , 0..FB_HEIGHT-1
 * \param[in] RGB pixel color
 * \see fb_RGB()
 */ 
void fb_fill_poly(uint32_t nb_pts, int* points, uint32_t RGB);


#endif
