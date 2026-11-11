#include <femtorv32.h>

void show_config() {
  static int mode = 0;
  printf("FemtoSOC config.\n");
  printf("\n");
  if(mode) {
    printf("[Processor]\n");
    printf(" Femtorv32 core\n");
    printf(" freq:   %d MHz\n",   FEMTORV32_FREQ);
    printf(" counter bits: %d\n", FEMTORV32_COUNTER_BITS);
    printf("  \n");
    printf("[RAM]\n");
    printf("  %d bytes\n", IO_IN(IO_HW_CONFIG_RAM));
  } else {
    printf("[Devices]\n");
    printf("  LEDs     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_LEDS_bit            ) ? '*' : ' ');
    printf("  UART     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_UART_DAT_bit        ) ? '*' : ' ');
    printf("  OLED     [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_SSD1351_DAT_bit     ) ? '*' : ' ');
    printf("  LedMtx   [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_MAX7219_DAT_bit     ) ? '*' : ' ');
    printf("  SPIFlash [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_MAPPED_SPI_FLASH_bit) ? '*' : ' ');
    printf("  FGA      [%c]\n",  FEMTOSOC_HAS_DEVICE(IO_FGA_CNTL_bit        ) ? '*' : ' ');
    printf("\n");
  }
//  *(volatile uint32_t*)(0x400004) = (~*(volatile uint32_t*)(0x400004)) & 0x1; // read and invert D1 LED/Pin
//  *(volatile uint32_t*)(0x400004) = (~*(volatile uint32_t*)(0x400004)) & 0x7; // read and invert D1 LED/Pin
  mode = !mode;
}

int main() {
    /*
     * redirects display to UART (default), OLED display
     * or led matrix, based on configured devices (in femtosoc.v).
     * Note: pulls the two fonts (eats up a subsequent part of the
     * available 6 Kbs).
     */
   //femtosoc_tty_init(); //commented out as prefers OLED over MAX
                          //and if falls though UART has alreadty been setup

   for(;;) {
      show_config();
      delay(10000);
   }

   return 0;
}
