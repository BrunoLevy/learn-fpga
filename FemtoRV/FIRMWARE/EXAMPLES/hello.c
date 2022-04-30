#include <femtorv32.h>
#include <femtoGL.h>

int main() {
    int i = 0;
   /*
    * redirects display to UART (default), OLED display
    * or led matrix, based on configured devices (in femtosoc.v).
    * Note: pulls the two fonts (eats up a subsequent part of the
    * available 6 Kbs).
    *   To save code size, on the IceStick, you can use 
    * instead MAX7219_tty_init() if you know you are 
    * using the led matrix, or GL_tty_init() if you know you are 
    * using the small OLED display.
    */
   femtosoc_tty_init();
   GL_set_font(&Font8x16);
   
   for(;;) {
     /* Using: "LIBFEMTORV32/HardwareConfig_bits.h" (derived from "HardwareConfig_bits.v")
      * IO_XXX = 1 << (IO_XXX_bit + 2); IO_LEDS_bit=0; --> (1<<(0+2))=4 --> 0x400004
      */
     *(volatile uint32_t*)(0x400004) = (~*(volatile uint32_t*)(0x400004)) & 0x1; // read and invert D1 LED/Pin
     
     delay(500);
     printf("Hello world !!\n Let me introduce myself, I am FemtoRV32, one of the smallest RISC-V cores\n");
     delay(500);
     i++;
     printf("Freq: %d MHz ; loop=%d ; LED D1=%d\n\n", FEMTORV32_FREQ, i, *(volatile uint32_t*)(0x400004));
   }

   return 0;
}

