/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick).
 This version uses floating-point numbers (much slower than mandelbrot_OLED.c
 that uses integer arithmetic).
*/

#include <femtorv32.h>

// To make it even slower !!
// #define float double

#define xmin -2.0
#define ymax  2.0
#define ymin -2.0
#define xmax  2.0
#define dx (xmax-xmin)/128.0
#define dy (ymax-ymin)/128.0

void mandel() {
   oled_write_window(0,0,127,127);
   float Ci = ymin;
   for(int Y=0; Y<128; ++Y) {
      float Cr = xmin;
      for(int X=0; X<128; ++X) {
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
	 OLED_WRITE_DATA_UINT16((iter << 19)|(iter << 2));
	 Cr += dx;
      }
      Ci += dy;
   }
}

int main() {
   for(;;) { 
       GL_tty_init();
       mandel();
       printf("Mandelbrot Demo.     \n");
       delay(1000);       
       GL_tty_goto_xy(0,127);
       printf("\n");
       printf("FemtoRV32 %d MHz\n", FEMTORV32_FREQ);   
       printf("FemtOS 1.0\n");
       // The 'terminal scrolling' functionality
       // also scrolls the graphics, funny !
       for(int i=0; i<13; i++) {
	   delay(100);
	   printf("\n");
       }
       delay(2000);
   }
   return 0;   
}



