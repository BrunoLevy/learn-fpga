#include <femtorv32.h>

void femtosoc_tty_init() {
     /* default mode is UART */
     uint32_t devices = IO_IN(IO_DEVICES_FREQ);
     if(devices & (1 << IO_DEVICE_SSD1351_BIT)) {
       /* If OLED screen is configured, redirect output to it */    
       GL_tty_init();
     } else if(devices & (1 << IO_DEVICE_MAX2719_BIT)) {
       /* else if LED matrix is configured, redirect output to it */           
       MAX7219_tty_init();
   }
}
