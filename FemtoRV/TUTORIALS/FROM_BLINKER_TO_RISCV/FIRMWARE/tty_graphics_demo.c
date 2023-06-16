#include "tty_graphics.h"
#include <math.h>

#ifdef __linux__
#include <stdlib.h>
#include <unistd.h>
#endif

// Size of the screen
// Replace with your own variables or values
#define graphics_width  80
#define graphics_height 40

int frame = 0;
float f = 0.0;

void do_pixel(int i, int j, float* R, float* G, float* B) {
    float x = (float)i;
    float y = (float)j;
    *R = 0.5f*(sin(x*0.1+f)+1.0);
    *G = 0.5f*(sin(y*0.1+2.0*f)+1.0);
    *B = 0.5f*(sin((x+y)*0.05-3.0*f)+1.0);
}

int main() {
    tty_graphics_init();   
    for(;;) {
	tty_graphics_fscan(graphics_width, graphics_height, do_pixel);
	f += 0.1;
        ++frame;
        tty_graphics_reset_colors();
        printf("frame = %d\n",frame);
#ifdef __linux__       
        usleep(40000);
#endif       
    }
    return 0;
}
