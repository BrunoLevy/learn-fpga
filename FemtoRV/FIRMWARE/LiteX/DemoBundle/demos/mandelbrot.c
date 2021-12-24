// Fixed-point mandelbrot
// Displays result on small OLED screen and
// in the terminal using ANSI color codes.

#include "demos.h"
#include "lite_oled.h"
#include <stdio.h>

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define xmin -2*mandel_mul
#define ymax  2*mandel_mul
#define ymin -2*mandel_mul
#define xmax  2*mandel_mul
#define dx (xmax-xmin)/OLED_HEIGHT
#define dy (ymax-ymin)/OLED_HEIGHT
#define norm_max (4 << mandel_shift)

void mandelbrot(void) {
   oled_init();
   oled_write_window(0,0,OLED_WIDTH-1,OLED_HEIGHT-1);
   int Ci = ymin;
   for(int Y=0; Y<OLED_HEIGHT; ++Y) {
      int Cr = xmin;
      for(int X=0; X<OLED_WIDTH; ++X) {
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
	 oled_data_uint16((iter << 19)|(iter << 2));
	 printf("\033[48;2;0;0;%dm ",iter << 4);
	 Cr += dx;
      }
      puts("\033[48;2;0;0;0m");      
      Ci += dy;
   }
}


