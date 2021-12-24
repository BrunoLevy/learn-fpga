#include "demos.h"
#include "lite_oled.h"

#include <stdio.h>
#include <libbase/uart.h>
#include <libbase/console.h>

static void oled_test(int nb_args, char** args) {
   uint32_t frame;
   puts("Press any key to exit");
   oled_init();
   oled_write_window(0,0,OLED_WIDTH-1,OLED_HEIGHT-1);
   for(;;) {
      for(uint32_t y=0; y<OLED_HEIGHT; ++y) {
	 for(uint32_t x=0; x<OLED_WIDTH; ++x) {
	    uint32_t R = (x+frame) & 63;
	    uint32_t G = (x >> 3)  & 63;
	    uint32_t B = (y+frame) & 63;
	    // pixel color: RRRRR GGGGG 0 BBBBB
	    oled_data_uint16(B | (G << 6) | (R << 11));
	 }
      }
      if (readchar_nonblock()) {
	getchar();
	break;
      }
      ++frame;
   }
   oled_off();
}

#ifdef CSR_OLED_SPI_BASE
define_demo(oled_test, "simple test for OLED screen");
#endif
