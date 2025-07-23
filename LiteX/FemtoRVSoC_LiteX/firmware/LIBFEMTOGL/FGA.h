
#define FGA_MODE_320x200x16bpp  0
#define FGA_MODE_320x200x8bpp   1
#define FGA_MODE_640x400x4bpp   2
#define FGA_MODE_800x600x2bpp   3
#define FGA_MODE_1024x768x1bpp  4
#define FGA_NB_MODES            5

/**************************************/

#define FGA_VBL_bit        (1 << 31)
#define FGA_HBL_bit        (1 << 30)
#define FGA_DA_bit         (1 << 29)
#define FGA_BUSY_bit       (1 << 28)

#define FGA_MODE_1bpp  0
#define FGA_MODE_2bpp  1
#define FGA_MODE_4bpp  2
#define FGA_MODE_8bpp  3
#define FGA_MODE_16bpp 4

#define FGA_COLORMAPPED (1 << 3)

#define FGA_REG_STATUS      0
#define FGA_REG_RESOLUTION  1
#define FGA_REG_COLORMODE   2
#define FGA_REG_DISPLAYMODE 3
#define FGA_REG_ORIGIN      4
#define FGA_REG_WRAP        5
#define FGA_REG_READREGID   6

#define FGA_MAGNIFY      1


#define FGA_CMD_SET_PALETTE_R (128 | 1)
#define FGA_CMD_SET_PALETTE_G (128 | 2)
#define FGA_CMD_SET_PALETTE_B (128 | 3)
#define FGA_CMD_SET_WWINDOW_X (128 | 4)
#define FGA_CMD_SET_WWINDOW_Y (128 | 5)
#define FGA_CMD_FILLRECT      (128 | 6)

#define FGA_SET_REG(REG, VAL)    IO_OUT(IO_FGA_CNTL, REG | ((VAL) << 8))
#define FGA_CMD0(CMD)            IO_OUT(IO_FGA_CNTL, CMD)
#define FGA_CMD1(CMD,ARG)        IO_OUT(IO_FGA_CNTL, CMD | ((ARG) << 8))
#define FGA_CMD2(CMD,ARG1, ARG2) IO_OUT(IO_FGA_CNTL, CMD | ((ARG1) << 8) | ((ARG2) << 20))
