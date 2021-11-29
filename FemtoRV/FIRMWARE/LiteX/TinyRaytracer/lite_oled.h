// This file is Copyright (c) 2021 Bruno Levy <Bruno.Levy@inria.fr>
//
// SSD1331 OLED screen driver

#ifndef LITE_OLED_H
#define LITE_OLED_H

#include <generated/csr.h>

// Display size in pixels
#define OLED_WIDTH   96
#define OLED_HEIGHT  64

// Constants for SPI protocol
#define OLED_SPI_CS_HIGH (0 << 0)
#define OLED_SPI_CS_LOW  (1 << 0)
#define OLED_SPI_LENGTH  (1 << 8)
#define OLED_SPI_DONE    (1 << 0)
#define OLED_SPI_START   (1 << 0)
#define OLED_SPI_CMD 2
#define OLED_SPI_DAT 3

/**
 * \brief Sends one byte to the SSD1331 OLED display using SPI protocol.
 * \param[in] cmd_or_dat one of OLED_SPI_CMD, OLED_SPI_DAT
 * \param[in] b the byte to be written
 */ 
static inline void oled_byte(uint8_t cmd_or_dat, uint8_t b) {
   oled_ctl_out_write(cmd_or_dat); // dc, resn, csn
   oled_spi_cs_write(OLED_SPI_CS_LOW);
   oled_spi_mosi_write(b);
   oled_spi_control_write(8*OLED_SPI_LENGTH | OLED_SPI_START);
   while(oled_spi_status_read() != OLED_SPI_DONE);
   oled_spi_cs_write(OLED_SPI_CS_HIGH);
}

/**
 * \brief Sends a command without arguments to the SSD1331 OLED display.
 * \details Refer to https://datasheetspdf.com/pdf-file/798763/SolomonSystech/SSD1331/1
 * \param[in] cmd the command
 */
static inline void oled0(uint8_t cmd) {
   oled_byte(OLED_SPI_CMD,cmd);
}

/**
 * \brief Sends a command with one argument to the SSD1331 OLED display.
 * \details Refer to https://datasheetspdf.com/pdf-file/798763/SolomonSystech/SSD1331/1
 * \param[in] cmd the command
 * \param[in] arg1 the argument
 */
static inline void oled1(uint8_t cmd, uint8_t arg1) {
   oled_byte(OLED_SPI_CMD,cmd);
   oled_byte(OLED_SPI_CMD,arg1);
}

/**
 * \brief Sends a command with two arguments to the SSD1331 OLED display.
 * \details Refer to https://datasheetspdf.com/pdf-file/798763/SolomonSystech/SSD1331/1
 * \param[in] cmd the command
 * \param[in] arg1 , arg2 the two arguments
 */
static inline void oled2(uint8_t cmd, uint8_t arg1, uint8_t arg2) {
   oled_byte(OLED_SPI_CMD,cmd);
   oled_byte(OLED_SPI_CMD,arg1);
   oled_byte(OLED_SPI_CMD,arg2);
}

/**
 * \brief Sends the initialization sequence to the SSD1331 OLED display.
 * \details Display content is random at startup.
 */ 
void oled_init(void);

/**
 * \brief Switches the display off.
 */ 
static inline void oled_off(void) {
   oled0(0xae); // display off   
}

/**
 * \brief Prepares data write for a window.
 * \param[in] x1 , y1 , x2 , y2 the bounds of the window.
 * \details Data is written using (x2-x1)*(y2-y1) calls to oled_data_uint16() or oled_data_rgb()
 */ 
static inline void oled_write_window(uint8_t x1, uint8_t y1, uint8_t x2, uint8_t y2) {
   oled2(0x15,x1,x2);
   oled2(0x75,y1,y2);
}

/**
 * \brief Writes the current pixel data.
 * \param[in] RGB the current pixel data, encoded as RRRRR GGGGG 0 BBBBB.
 * \see oled_write_window().
 */ 
static inline void oled_data_uint16(uint16_t RGB) {
   // Note: is it possible to send 16 bits in one go ?
   // Probably yes, using something like:
   //  oled_spi_control_write(16*OLED_SPI_LENGTH | OLED_SPI_START);
   // I tried but it did not work...
   oled_byte(OLED_SPI_DAT,(uint8_t)(RGB>>8));   
   oled_byte(OLED_SPI_DAT,(uint8_t)(RGB));
}

/**
 * \brief Converts three components into a 16 bits pixel value.
 * \param[in]  R , G , B the three components, between 0 and 255.
 * \return the 16-bits pixel value, encoded as RRRRR GGGGG 0 BBBBB
 */ 
static inline uint16_t oled_RGB_to_uint16(uint16_t R, uint16_t G, uint16_t B) {
   return (((((R & 0xF8) << 5) | (G & 0xF8)) << 3) | (B >> 3));
}

/**
 * \brief Writes the current pixel data.
 * \param[in]  R , G , B the three components, between 0 and 255.
 * \see oled_write_window()
 */
static inline void oled_data_RGB(uint8_t R, uint8_t G, uint8_t B) {
   oled_data_uint16(oled_RGB_to_uint16(R,G,B));
}

/**
 * \brief Sets a pixel, color specified as 16-bits value.
 * \param[in] x , y pixel coordinates, in [0..OLED_WIDTH-1],[0..OLED_HEIGHT-1]
 * \param[in] rgb 16-bits pixel value, encoded as RRRRR GGGGG 0 BBBBB
 * \see oled_setpixel_RGB(), oled_RGB_to_uint16()
 */ 
static inline void oled_setpixel_uint16(uint8_t x, uint8_t y, uint16_t rgb) {
   oled_write_window(x,y,x,y);
   oled_data_uint16(rgb);
}

/**
 * \brief Sets a pixel, color specified as R,G,B components.
 * \param[in] x , y pixel coordinates, in [0..OLED_WIDTH-1],[0..OLED_HEIGHT-1]
 * \param[in] R , G , B color components, in [0..255]
 * \see oled_setpixel_uint16()
 */ 
static inline void oled_setpixel_RGB(
   uint8_t x, uint8_t y, uint8_t R, uint8_t G, uint8_t B
) {
   oled_setpixel_uint16(x,y,oled_RGB_to_uint16(R,G,B));
}

/**
 * \brief Fills a rectangle, color specified as 16-bits value.
 * \param[in] x1 , y1 , x2, y2 rectanble bounds, in [0..OLED_WIDTH-1],[0..OLED_HEIGHT-1]
 * \param[in] rgb 16-bits pixel value, encoded as RRRRR GGGGG 0 BBBBB
 * \see oled_fillrect_RGB(), oled_RGB_to_uint16()
 */ 
void oled_fillrect_uint16(
   uint8_t x1, uint8_t y1,
   uint8_t x2, uint8_t y2,
   uint16_t rgb
);			  

/**
 * \brief Fills a rectangle, color specified as 16-bits value.
 * \param[in] x1 , y1 , x2, y2 rectanble bounds, in [0..OLED_WIDTH-1],[0..OLED_HEIGHT-1]
 * \param[in] R , G , B color components, in [0..255]
 * \see oled_fillrect_uint16(), oled_RGB_to_uint16()
 */ 
static inline void oled_fillrect_RGB(
   uint8_t x1, uint8_t y1,
   uint8_t x2, uint8_t y2,
   uint8_t R, uint8_t G, uint8_t B				     
) {
   oled_fillrect_uint16(x1,y1,x2,y2,oled_RGB_to_uint16(R,G,B));
}

/**
 * \brief Clears the screen.
 */ 
void oled_clear(void);
   
#endif


