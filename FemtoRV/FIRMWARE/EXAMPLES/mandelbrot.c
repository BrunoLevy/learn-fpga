/*
 Computes and displays the Mandelbrot set on the OLED display.
 (needs an SSD1351 128x128 OLED display plugged on the IceStick)
 If you do not have the OLED display, use mandelbrot_terminal.s 
 instead.
 Note: there is also an assembly version in EXAMPLES/mandelbrot_OLED.s.
*/

#include <femtoGL.h>

#define W GL_width
#define H GL_height

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define xmin -2*mandel_mul
#define ymax  2*mandel_mul
#define ymin -2*mandel_mul
#define xmax  2*mandel_mul
#define dx (xmax-xmin)/H
#define dy (ymax-ymin)/H
#define norm_max (4 << mandel_shift)

int indexed = 0;

void mandel() {
   GL_write_window(0,0,W-1,H-1);
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
	 if(indexed) {
	    GL_WRITE_DATA_UINT16(iter==0?0:(iter%15)+1);
	 } else {
	    GL_WRITE_DATA_UINT16((iter << 19)|(iter << 2));
	 }
	  
	 Cr += dx;
      }
      Ci += dy;
   }
}

#ifdef FGA
uint8_t palette[16][3];
#endif

int main() {
   GL_init(GL_MODE_CHOOSE);
   

   GL_clear();
#ifdef FGA
   palette[0][0] = 0;
   palette[0][1] = 0;
   palette[0][2] = 0;
   FGA_setpalette(0, palette[0][0], palette[0][1], palette[0][2]);
   for(int i=1; i<16; ++i) {
      palette[i][0] = random() & 255;
      palette[i][1] = random() & 255;
      palette[i][2] = random() & 255;      
      FGA_setpalette(i, palette[i], palette[i], palette[i]);
   }
   indexed = (FGA_mode == FGA_MODE_320x200x8bpp ||
              FGA_mode == FGA_MODE_640x400x4bpp  );
#endif   
   mandel();
   
#ifdef FGA   
   for(;;) {
      GL_wait_vbl();
      for(int i=15; i>1; --i) {
	 palette[i][0] = palette[i-1][0];
	 palette[i][1] = palette[i-1][1];
	 palette[i][2] = palette[i-1][2]; 
	 FGA_setpalette(i, palette[i][0], palette[i][1], palette[i][2]);	 
      }
      palette[1][0] = random() & 255;
      palette[1][1] = random() & 255;
      palette[1][2] = random() & 255;
      FGA_setpalette(0, palette[0][0], palette[0][1], palette[0][2]);
      delay(100);
   }
#endif
   
   return 0;   
}



