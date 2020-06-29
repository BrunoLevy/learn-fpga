#include <femtorv32.h>

void show_config() {
   uint32_t devices = CONFIGWORDS[CONFIGWORD_DEVICES];
   printf("FemtoSOC config.\n");
   printf("\n");
   printf("[Processor]\n");
   printf("  Femtorv32 core\n");
   printf("  2shifter [%c]\n", (CONFIGWORDS[CONFIGWORD_PROC] & (1 << 31)) ? '*' : ' ');
   printf("  freq:    %d MHz\n",  CONFIGWORDS[CONFIGWORD_PROC_FREQ]);
   printf("[RAM]\n");
   printf("  %d bytes\n", CONFIGWORDS[CONFIGWORD_RAM]);
   printf("[Devices]\n");
   printf("  LEDs     [%c]\n",  devices & CONFIGWORD_DEVICE_LEDS      ? '*' : ' ');
   printf("  UART     [%c]\n",  devices & CONFIGWORD_DEVICE_UART      ? '*' : ' ');
   printf("  OLED     [%c]\n",  devices & CONFIGWORD_DEVICE_SSD1351   ? '*' : ' ');
   printf("  LedMtx   [%c]\n",  devices & CONFIGWORD_DEVICE_MAX2719   ? '*' : ' ');
   printf("  SPIFlash [%c]\n",  devices & CONFIGWORD_DEVICE_SPI_FLASH ? '*' : ' ');
   printf("\n");
}



int main() {
   uint32_t devices = CONFIGWORDS[CONFIGWORD_DEVICES];
   if(devices & CONFIGWORD_DEVICE_SSD1351) {
      GL_tty_init();
   }
   
   for(;;) {
      show_config();
      delay(3000);
   }
   
   return 0;
}
