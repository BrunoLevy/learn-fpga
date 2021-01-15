/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick)
 If you do not have the OLED display, use mandelbrot_terminal.s 
 instead.
 Note: there is also an assembly version in EXAMPLES/mandelbrot_OLED.s.
*/

#include <femtorv32.h>

#define W 128
#define H 128

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define xmin -2*mandel_mul
#define ymax  2*mandel_mul
#define ymin -2*mandel_mul
#define xmax  2*mandel_mul
#define dx (xmax-xmin)/H
#define dy (ymax-ymin)/H
#define norm_max (4 << mandel_shift)

int main() {
   GL_init();
   GL_fill_rect(0,0,W-1,H-1,0);
   oled_write_window(0,0,W-1,H-1);
   int Ci = ymin;
   for(int Y=0; Y<H; ++Y) {
      int Cr = xmin;
      for(int X=0; X<W; ++X) {
	 int Zr = Cr;
	 int Zi = Ci;
	 int iter = 15;
	 while(iter > 0) {
	    int Zrr = (Zr * Zr) >> mandel_shift;
	    int Zii = (Zi * Zi) >> mandel_shift;
	    int Zri = (Zr * Zi) >> (mandel_shift - 1);
	    Zr = Zrr - Zii + Cr;
	    Zi = Zri + Ci;
	    if(Zrr + Zii > norm_max) {
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

