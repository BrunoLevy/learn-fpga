#include <femtorv32.h>

void show_config() {
   uint32_t devices = CONFIGWORDS[CONFIGWORD_DEVICES];
   printf("FemtoSOC config.\n");
   printf("\n");
   printf("[Processor]\n");
   printf("  Femtorv32 core\n");
   printf("  counters: [%c]\n", (CONFIGWORDS[CONFIGWORD_PROC] & 1) ? '*' : ' ');
   printf("  count64:  [%c]\n", (CONFIGWORDS[CONFIGWORD_PROC] & 2) ? '*' : ' ');
   printf("  RV32M:    [%c]\n", (CONFIGWORDS[CONFIGWORD_PROC] & 3) ? '*' : ' ');   
   printf("  freq:    %d MHz\n",  CONFIGWORDS[CONFIGWORD_PROC_FREQ]);
   printf("[RAM]\n");
   printf("  %d bytes\n", CONFIGWORDS[CONFIGWORD_RAM]);
   printf("[Devices]\n");
   printf("  LEDs     [%c]\n",  devices & CONFIGWORD_DEVICE_LEDS      ? '*' : ' ');
   printf("  UART     [%c]\n",  devices & CONFIGWORD_DEVICE_UART      ? '*' : ' ');
   printf("  OLED     [%c]\n",  devices & CONFIGWORD_DEVICE_SSD1351   ? '*' : ' ');
   printf("  LedMtx   [%c]\n",  devices & CONFIGWORD_DEVICE_MAX7219   ? '*' : ' ');
   printf("  SPIFlash [%c]\n",  devices & CONFIGWORD_DEVICE_SPI_FLASH ? '*' : ' ');
   printf("\n");
}



int main() {
    /*
     * redirects display to UART (default), OLED display
     * or led matrix, based on configured devices (in femtosoc.v).
     * Note: pulls the two fonts (eats up a subsequent part of the
     * available 6 Kbs).
     */
   femtosoc_tty_init();
   
   for(;;) {
      show_config();
      delay(3000);
   }
   
   return 0;
}
