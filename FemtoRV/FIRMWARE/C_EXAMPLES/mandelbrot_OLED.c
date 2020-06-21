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

void mandel() {
   oled_write_window(0,0,127,127);
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
	 OLED_WAIT(); 
	 IO_OUT(IO_OLED_DATA,iter << 2);
	 OLED_WAIT();
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
       printf("FemtoRV32 60 MHz\n");   
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



