/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick).
 This version uses floating-point numbers (much slower than mandelbrot_OLED.c
 that uses integer arithmetic).
*/

#include <femtorv32.h>

// To make it even slower !!
// #define float double

#define W 128
#define H 128

#define xmin -2.0
#define ymax  2.0
#define ymin -2.0
#define xmax  2.0
#define dx (xmax-xmin)/(float)H
#define dy (ymax-ymin)/(float)H

int main() {
   GL_init();
   GL_clear();
   oled_write_window(0,0,W-1,H-1);
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
	 IO_OUT(IO_SSD1351_DAT16,(iter << 19)|(iter << 2));	 
	 Cr += dx;
      }
      Ci += dy;
   }
   int i=0;
   for(;;) {
      i=i+1;
      LEDS(i >> 13);
   }
}
