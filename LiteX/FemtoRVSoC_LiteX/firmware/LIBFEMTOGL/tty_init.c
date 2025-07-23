#include <femtoGL.h>

void femtosoc_tty_init() {
   
   /* default mode is UART */
   if(FEMTOSOC_HAS_DEVICE(IO_SSD1351_CNTL_bit)) {
      /* If OLED screen is configured, redirect output to it */    
      GL_tty_init(GL_MODE_OLED);
   } else if(FEMTOSOC_HAS_DEVICE(IO_MAX7219_DAT_bit)) {
      /* else if LED matrix is configured, redirect output to it */           
      MAX7219_tty_init();
   } 
}
