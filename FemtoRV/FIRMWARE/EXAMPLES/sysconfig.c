#include <femtorv32.h>

void show_config() {
  printf("FemtoSOC config.\n");
  printf("\n");
  printf("[Processor]\n");
  printf("  Femtorv32 core\n");
  printf("  freq:    %d MHz\n", FEMTORV32_FREQ);
  printf("   CPL:    %d\n",     FEMTORV32_CPL);  
  printf("[RAM]\n");
  printf("  %d bytes\n", IO_IN(IO_RAM));
  printf("[Devices]\n");
  printf("  LEDs     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_DEVICE_LEDS_BIT     ) ? '*' : ' ');
  printf("  UART     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_DEVICE_UART_BIT     ) ? '*' : ' ');
  printf("  OLED     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_DEVICE_SSD1351_BIT  ) ? '*' : ' ');
  printf("  LedMtx   [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_DEVICE_MAX2719_BIT  ) ? '*' : ' ');
  printf("  SPIFlash [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_DEVICE_SPI_FLASH_BIT) ? '*' : ' ');
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
