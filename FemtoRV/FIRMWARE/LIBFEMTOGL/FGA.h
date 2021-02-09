#define FGA_MODE_320x200x16bpp  0
#define FGA_MODE_320x200x8bpp   1
#define FGA_MODE_640x400x4bpp   2

#define FGA_SET_MODE        0
#define FGA_SET_PALETTE_R   1 
#define FGA_SET_PALETTE_G   2 
#define FGA_SET_PALETTE_B   3 
#define FGA_SET_WWINDOW_X   4
#define FGA_SET_WWINDOW_Y   5
#define FGA_SET_ORIGIN      6
#define FGA_FILLRECT        7

#define FGA_VBL_bit        (1 << 31)
#define FGA_HBL_bit        (1 << 30)
#define FGA_DA_bit         (1 << 29)
#define FGA_BUSY_bit       (1 << 28)

