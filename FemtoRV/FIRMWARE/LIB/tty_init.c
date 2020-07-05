#include <femtorv32.h>

void femtosoc_tty_init() {
   uint32_t devices = CONFIGWORDS[CONFIGWORD_DEVICES];
   if(devices & CONFIGWORD_DEVICE_SSD1351) {
      GL_tty_init();
   } else if(devices & CONFIGWORD_DEVICE_MAX2719) {
      MAX2719_tty_init();
   }
}
