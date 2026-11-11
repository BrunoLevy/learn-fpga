#include <femtorv32.h>
#include <femtoGL.h>
int sram_x     =   0xBEEFCAFE;

int sram_y[]    = {0x40414243,
                                0x44454647,
                                0x48494a4b,
                                0x4c4d4e4f,
                                0x50515253,
                                0x54555657,
                                0x00000000,
                                0xdeadbeef}; //7th element


int sram_z    =   0x12345678;

#ifdef PASSzpq
static int z = 0;
int update_led(int z) RV32_SRAMCODE ;
int update_led(int z)
{
   z += 4;
   if (z > 12) z = 4;
   IO_OUT(IO_LEDS, z);
   return z;
}
#else

void update_led(void) RV32_SRAMCODE ;
void update_led(void)
{
   static int z = 0;
   z += 4;
   if (z > 12) z = 4;
   IO_OUT(IO_LEDS, z);
}

#endif

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
    GL_set_font(&Font8x16);

   int sram_base = 0x101000;

  
    
    int sram_lasttrenzword = 0x1FFFFC;
    int sram_alias_lasttrenzword = 0x17FFFC;
    *(uint32_t*)(sram_lasttrenzword) = 0x76543210;
    *(uint32_t*)(sram_alias_lasttrenzword) = 0xCAFEFEED;
           
   *(uint32_t*)(0x101000) = 0x43424140;
   *(uint32_t*)(0x101004) = 0x47464544;
   *(uint32_t*)(0x101008) = 0x4b4a4948;
   *(uint32_t*)(0x10100C) = 0x4f4e4d4c;
   *(uint32_t*)(0x101010) = 0x50515253;
   *(uint32_t*)(0x101014) = 0x54555657;

   const int bright = 0x1f;
   const int dark = 0x0; 
   int zzz = 4;
   int frame = 0;
   int k = 0;
   int s = 10; //halfword offset
   char t = *(uint8_t*)(sram_base+k);
   unsigned short u = *(uint16_t*)(sram_base+s);
   *(uint8_t*)(sram_base+k) = '!';
   *(uint8_t*)(sram_base+s) = '.';
   *(uint8_t*)(sram_base+s+1) = '.';
   short v = *(uint16_t*)(sram_base+s);
   for(;;) {
     /* Using: "LIBFEMTORV32/HardwareConfig_bits.h" (derived from "HardwareConfig_bits.v")
      * IO_XXX = 1 << (IO_XXX_bit + 2); IO_LEDS_bit=0; --> (1<<(0+2))=4 --> 0x400004
      */
     // *(volatile uint32_t*)(0x400004) = (~*(volatile uint32_t*)(0x400004)) & 0x1; // read and invert D1 LED/Pin
     //delay(500);
     //printf("Hello world !!\n Let me introduce myself, I am FemtoRV32, one of the smallest RISC-V cores\n");
     
     if (i>20) {
           delay(400);
           i = 0; 
           printf("y0 %x\n",sram_y[0]);
           printf("y1 %x\n",sram_y[1]);
           printf("y6 %x\n",sram_y[6]);
           printf("y7 %x\n",sram_y[7]);
        
           printf("%x\n",sram_x);
           printf("%x\n",sram_z);
           printf("%x \n",*(uint32_t*)(sram_lasttrenzword));
           printf("\033[H");
           printf("Freq: %d MHz ; loop=%d ; LED D1=%d\n\n", FEMTORV32_FREQ, frame, *(volatile uint32_t*)(0x400004));
           //printf("Freq: %d MHz ; loop=%d\n\n", FEMTORV32_FREQ, frame); this also locks up s+=2
           //printf("Freq: %d MHz\n\n", FEMTORV32_FREQ); this also locks up when s+=2
           //printf("ABC %x\n", frame);
           //printf("ABC\n");
           //printf("Freq: %d MHz ; loop=%d ; LED D1=%d\n\n", FEMTORV32_FREQ, frame, *(volatile uint32_t*)(0x400004));
           frame++;
           *(uint8_t*)(sram_base+k) = t;
           if (!(k&1)) //needs to move at half the pace of byte write to avoid overtake of test pattern
           {
               *(uint16_t*)(sram_base+s) = u;
              // *(uint8_t*)(sram_base+s+0)= u&0xff;
              // *(uint8_t*)(sram_base+s+1)= (u&0xff00)>>8;    
              
              s+=2;
              //s=12;
              //s+=4;
              //s+=0;
              //printf("\ns=%d\n",s);
              
              if (s>20) s = 0;
              
              
              u = *(uint16_t*)(sram_base+s);
              IO_OUT(IO_LEDS, bright);
               *(uint16_t*)(sram_base+s) = v;
#if 0                  
              IO_OUT(IO_LEDS, zzz);
              zzz+=4;
              if (zzz > 12) zzz = 4;
#else
#ifdef PASSzpq
              z = update_led(z);
#else
              update_led();
#endif
#endif
              //  *(uint8_t*)(sram_base+s+0)= v&0xff;
              //  *(uint8_t*)(sram_base+s+1)= (v&0xff00)>>8;
              //IO_OUT(IO_LEDS, dark);      

           }
           
           k++;
           if (k>20) k = 0;

           t = *(uint8_t*)(sram_base+k);
          *(uint8_t*)(sram_base+k) = '!';

     }



//     int j;

     for (int j = 0; j<4; j++) {printf("%c",*(uint8_t*)(sram_base+i+j));}

     printf(":");
 #if 0
     for (int j = 0; j<4; j++) {
          uint8_t m = *(uint8_t*)(sram_base+i+j);
          uint8_t h = m>>4;
          putchar("0123456789ABCDEF"[h]);
          putchar("0123456789ABCDEF"[m&0xf]);
          if (j != 3) putchar(',');
     }
#else
     printf("%x,", *(uint8_t*)(sram_base+i+0));
     printf("%x,", *(uint8_t*)(sram_base+i+1));
     printf("%x,", *(uint8_t*)(sram_base+i+2));
     printf("%x->", *(uint8_t*)(sram_base+i+3));
#endif
     printf("[%x] = %x\n", sram_base+i, *(uint32_t*)(sram_base+i));
//     printf("\n");

     i+=4;
     

    // printf("\n");

   }

   return 0;
}

