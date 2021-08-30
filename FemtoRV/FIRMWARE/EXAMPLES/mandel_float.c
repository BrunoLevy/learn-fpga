/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick).
 This version uses floating-point numbers (much slower than mandelbrot_OLED.c
 that uses integer arithmetic).
*/

#include <femtoGL.h>

// To make it even slower !!
// #define float double

#define W GL_width
#define H GL_height

#define xmin -2.0
#define ymax  2.0
#define ymin -2.0
#define xmax  2.0

#define dx 0.03125f
#define dy 0.03125f

void mandel() {
   
//   float dx = (xmax-xmin)/(float)H;
//   float dy = (ymax-ymin)/(float)H;
   
   uint32_t total_ticks = 0;
   GL_write_window(0,0,W-1,H-1);
   float Ci = ymin;
   for(int Y=0; Y<H; ++Y) {
      float Cr = xmin;
      for(int X=0; X<W; ++X) {
	 float Zr = Cr;
	 float Zi = Ci;
	 int iter = 15;
	 while(iter > 0) {
	     float Zrr = (Zr * Zr);
	     float Zii = (Zi * Zi);
	     float Zri = 2.0 * (Zr * Zi);
	     Zr = Zrr - Zii + Cr;
	     Zi = Zri + Ci;
	     if(Zrr + Zii > 4.0) {
		 break;
	     }
	     --iter;
	 }
	 GL_WRITE_DATA_UINT16((iter << 19)|(iter << 2));
	 Cr += dx;
      }
      Ci += dy;
   }
}

int main() {
   for(;;) {
      GL_init(GL_MODE_CHOOSE);
      GL_tty_init(FGA_mode);   
#ifdef FGA
      FGA_setpalette(0, 0, 0, 0);
      for(int i=1; i<255; ++i) {
	 FGA_setpalette(i, random(), random(), random());
      }
#endif   
      GL_clear();
      mandel();
      UART_putchar(4); // send <ctrl><D> to UART (exits simulation)
    
      GL_tty_goto_xy(0,0);
      printf("Mandelbrot Demo.\n");
      delay(1000);       
      GL_tty_goto_xy(0,GL_height-1);
      printf("\n");
      printf("FemtoRV32 %d MHz\n", FEMTORV32_FREQ);   
      printf("FemtOS 1.0\n");
      delay(2000);
   }
   return 0;   
}



