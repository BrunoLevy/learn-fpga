/*
 * Graphics library demo.
 */ 

#include <femtoGL.h>

void random_pixel() {
    int x = random() % GL_width;
    int y = random() % GL_height;
    int col = random();
    GL_setpixel(x,y,col);
}

void random_line() {
    int x1 = random() % GL_width;
    int y1 = random() % GL_height;
    int x2 = random() % GL_width;
    int y2 = random() % GL_height;
    int col = random();
    GL_line(x1,y1,x2,y2,col);
}

void random_rect() {
    int tmp;
    int x1 = random() % GL_width;
    int y1 = random() % GL_height;
    int x2 = random() % GL_width;
    int y2 = random() % GL_height;
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

/*
 * Note: there is a much faster way of 
 * doing that, using GL_write_window() 
 * and directly outputting pixels to the 
 * driver, see test_OLED.c and test_OLED.s
 */ 
void show_colors() {
    GL_write_window(0,0,GL_width-1,GL_height-1);
    for(int y=0; y<GL_height; ++y) {
	for(int x=0; x<GL_width; ++x) {
	    int r = x << 1;
	    int g = x << 8;
	    int b = y << 1;
	    GL_WRITE_DATA_RGB(r,g,b);
	}
    }
}

void show_text() {
   printf("All work and no play makes Jack a dull boy.\n");
   delay(100);
   printf("The quick brown fox jumps over the lazy dog.\n");
   delay(100);	
}

int main() {
    int cnt = 0;
    GL_init(GL_MODE_CHOOSE);
    GL_clear();
    show_colors();
#ifdef FGA
    FGA_setpalette(0,0,0,0);
    for(int i=1; i<255; ++i) {
       FGA_setpalette(i, random()&255, random()&255, random()&255);
    }
#endif
    delay(1000);
    GL_clear();
    for(cnt=0; cnt<5000; ++cnt) {
	random_pixel();
    }
    delay(1000);
    GL_clear();
    for(cnt=0; cnt<1000; ++cnt) {
	random_line();
    }
    delay(1000);
    GL_clear();    
    for(cnt=0; cnt<1000; ++cnt) {
	random_rect();
    }
    GL_tty_init(FGA_mode);
    GL_set_font(&Font3x5);
    show_text();
    GL_set_font(&Font5x6);
    show_text();
    GL_set_font(&Font8x8);
    show_text();
    GL_set_font(&Font8x16);
    show_text();
    return 0;
 }
