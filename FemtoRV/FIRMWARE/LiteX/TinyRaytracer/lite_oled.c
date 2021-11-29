// This file is Copyright (c) 2021 Bruno Levy <Bruno.Levy@inria.fr>
//
// SSD1331 OLED screen driver

#include "lite_oled.h"

void oled_init(void) {
   oled0(0xae);       // display off
   oled1(0x81, 0x91); // contrast A
   oled1(0x82, 0x50); // contrast B
   oled1(0x83, 0x7d); // contrast C
   oled1(0x87, 0x06); // master current control
   oled1(0x8a, 0x64); // prechargeA
   oled1(0x8b, 0x78); // prechargeB
   oled1(0x8c, 0x64); // prechargeC
   oled1(0xa0, 0x60); // RGB mode and remap
   oled1(0xa1, 0x00); // startline
   oled1(0xa2, 0x00); // display offset
   oled0(0xa4);       // normal display	
   oled1(0xa8, 0x3f); // set multiplex
   oled1(0xad, 0x8e); // set master
   oled1(0xb0, 0x00); // powersave mode 
   oled1(0xb1, 0x31); // phase period adjustment
   oled1(0xb3, 0xf0); // clock div
   oled1(0xbb, 0x3a); // prechargelevel
   oled1(0xbe, 0x3e); // vcomh
   oled0(0x2e);       // disable scrolling
   oled_clear();      // clears the screen
   oled0(0xaf);       // display on
}

void oled_fillrect_uint16(
   uint8_t x1, uint8_t y1,
   uint8_t x2, uint8_t y2,
   uint16_t rgb
) {
   uint32_t nb_pixels = (uint32_t)(x2-x1+1)*(uint32_t)(y2-y1+1);
   oled_write_window(x1,y1,x2,y2);
   for(uint32_t i=0; i<nb_pixels; ++i) {
      oled_data_uint16(rgb);
   }
}

void oled_clear(void) {
   oled_fillrect_uint16(0,0,OLED_WIDTH-1,OLED_HEIGHT-1,0);
}
