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

int main() {
    int cnt = 0;
    GL_init(GL_MODE_CHOOSE_RGB);
    GL_clear();
    show_colors();
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
    GL_tty_init();
    for(int i=0; i<20; ++i) {
	printf("All work and no play makes Jack a dull boy.\n");
	delay(100);
	printf("The quick brown fox jumps over the lazy dog.\n");
	delay(100);	
    }
    return 0;
 }
