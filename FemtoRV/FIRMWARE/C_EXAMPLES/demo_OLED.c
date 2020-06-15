/*
 * Graphics library demo.
 */ 

#include <femtorv32.h>

void random_rect() {
    int tmp;
    int x1 = random() & 127;
    int y1 = random() & 127;
    int x2 = random() & 127;
    int y2 = random() & 127;
    int col = random();
    if(x1 > x2) {
	tmp = x1;
	x1 = x2;
	x2 = tmp;
    }
    if(y1 > y2) {
	tmp = y1;
	y1 = y2;
	y2 = tmp;
    }
    GL_fill_rect(x1,y1,x2,y2,col);
}

void random_pixel() {
    int x = random() % 127;
    int y = random() % 127;
    int col = random();
    GL_setpixel(x,y,col);
}

/*
 * Note: there is a much faster way of 
 * doing that, using oled_write_window() 
 * and directly outputting pixels to the 
 * driver, see test_OLED.c and test_OLED.s
 */ 
void show_colors() {
    for(int y=0; y<128; ++y) {
	for(int x=0; x<128; ++x) {
	    int r = x << 1;
	    int g = x << 8;
	    int b = y << 1;
	    GL_setpixel_RGB(x,y,r,g,b);
	}
    }
}

int main() {
    int cnt = 0;
    GL_init();
    GL_clear();
    show_colors();
    delay(2000);
    GL_clear();
    for(cnt=0; cnt<50000; ++cnt) {
	random_pixel();
    }
    delay(2000);
    GL_clear();    
    for(cnt=0; cnt<2000; ++cnt) {
	random_rect();
    }
}
