/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick)
 If you do not have the OLED display, use mandelbrot_terminal.s 
 instead.
 Note: there is also an assembly version in EXAMPLES/mandelbrot_OLED.s.
*/

#include <femtorv32.h>

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define xmin -2*mandel_mul
#define ymax  2*mandel_mul
#define ymin -2*mandel_mul
#define xmax  2*mandel_mul
#define dx (xmax-xmin)/128
#define dy (ymax-ymin)/128
#define norm_max (4 << mandel_shift)

int main() {
   oled_init();
   oled_clear();
   oled2(0x15,0x00,0x7f); // column address
   oled2(0x75,0x00,0x7f); // row address
   oled0(0x5c);           // write RAM
   
   int Ci = ymin;
   for(int Y=0; Y<128; ++Y) {
      int Cr = xmin;
      for(int X=0; X<128; ++X) {
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
	 IO_OUT(IO_OLED_DATA,iter << 3);
	 oled_wait(); 
	 IO_OUT(IO_OLED_DATA,iter << 2);
	 oled_wait();
	 Cr += dx;
      }
      Ci += dy;
   }

   return 0;   
}





