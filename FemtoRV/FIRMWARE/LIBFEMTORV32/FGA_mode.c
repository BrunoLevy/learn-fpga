#include <femtorv32.h>

#define SET_MODE       0
#define SET_PALETTE_R  1
#define SET_PALETTE_G  2
#define SET_PALETTE_B  3
#define SET_WWINDOW_X  4
#define SET_WWINDOW_Y  5

void FGA_setmode(int mode) {
   IO_OUT(IO_FGA_CNTL, 0 | (mode << 8));
}

void FGA_write_window(uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
  IO_OUT(IO_FGA_CNTL, SET_WWINDOW_X | x1 << 8 | x2 << 20);
  IO_OUT(IO_FGA_CNTL, SET_WWINDOW_Y | y1 << 8 | y2 << 20);  
}

/***************************************************************************/

