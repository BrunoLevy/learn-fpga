/*
 Computes and displays the Mandelbrot set on the OLED display.
*/

#include <stdio.h>

#ifdef __linux__
#include <unistd.h>
#else
#include "io.h"
#endif

#define W 46
#define H 46

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define xmin -2*mandel_mul
#define ymax  2*mandel_mul
#define ymin -2*mandel_mul
#define xmax  2*mandel_mul
#define dx (xmax-xmin)/H
#define dy (ymax-ymin)/H
#define norm_max (4 << mandel_shift)


#define ANSIRGB(R,G,B) "\033[48;2;" #R ";"  #G ";" #B "m  "


const char* colormap[21] = {
   ANSIRGB( 0, 0,  0),
   ANSIRGB( 0, 0, 40),
   ANSIRGB( 0, 0, 80),
   ANSIRGB( 0, 0,120),
   ANSIRGB( 0, 0,160),
   ANSIRGB( 0, 0,200),
   ANSIRGB( 0, 0,240),
   
   ANSIRGB( 0,  0, 0),
   ANSIRGB( 0, 40, 0),
   ANSIRGB( 0, 80, 0),
   ANSIRGB( 0,120, 0),
   ANSIRGB( 0,160, 0),
   ANSIRGB( 0,200, 0),
   ANSIRGB( 0,240, 0),

   ANSIRGB(   0, 0, 0),
   ANSIRGB(  40, 0, 0),
   ANSIRGB(  80, 0, 0),
   ANSIRGB( 120, 0, 0),
   ANSIRGB( 160, 0, 0),
   ANSIRGB( 200, 0, 0),
   ANSIRGB( 240, 0, 0)
};

int main() {
   int frame=0;
   for(;;) {
      IO_OUT(IO_LEDS,frame);
      int last_color = -1;
      printf("\033[H");
      int Ci = ymin;
      for(int Y=0; Y<H; ++Y) {
	 int Cr = xmin;
	 for(int X=0; X<W; ++X) {
	    int Zr = Cr;
	    int Zi = Ci;
	    int iter = 20;
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
	    int color = (iter+frame)%21;
	    printf(color == last_color ? "  " : colormap[color]);
	    last_color = color;
	    Cr += dx;
	 }
	 Ci += dy;
	 printf("\033[49m\n");	 
	 last_color = -1;
      }
      ++frame;
#ifdef __linux__       
        usleep(100000);
#endif
//      if(frame>4) break;
   }
   
}



