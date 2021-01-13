#include <femtorv32.h>

void show_config() {
  static int mode = 0;
  printf("FemtoSOC config.\n");
  printf("\n");
  if(mode) {
    printf("[Processor]\n");
    printf(" Femtorv32 core\n");
    printf(" freq:   %d MHz\n", FEMTORV32_FREQ);
    printf("  CPL:   %d\n",     FEMTORV32_CPL);
    printf("  \n");
    printf("[RAM]\n");
    printf("  %d bytes\n", IO_IN(IO_HW_CONFIG_RAM));
  } else {
    printf("[Devices]\n");
    printf("  LEDs     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_LEDS_bit       ) ? '*' : ' ');
    printf("  UART     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_UART_DAT_bit   ) ? '*' : ' ');
    printf("  OLED     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_SSD1351_DAT_bit) ? '*' : ' ');
    printf("  LedMtx   [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_MAX7219_DAT_bit) ? '*' : ' ');
    printf("  SPIFlash [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_SPI_FLASH_bit  ) ? '*' : ' ');
    printf("  FGA      [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_FGA_CNTL_bit   ) ? '*' : ' ');
    printf("\n");
  }
  mode = !mode;
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
