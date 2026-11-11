/*
2023Jan01 Nick Hebdon
Code based on SSD1306 avr library by Matiasus
https://github.com/Matiasus/SSD1306
tag "v3.0.0" 8ca673c

For use this SeeedStudio Expansion Board

2026feb02 Nick Hebdon testing in LearnFpga
*/
#include <femtorv32.h>
#include "ssd1306.h"


 

unsigned short int _indexCol = START_COLUMN_ADDR;
unsigned short int _indexPage = START_PAGE_ADDR;


 int ssd1306_send_command_stream(int chan, int addr, byte* pCommands, int len)
{
  byte cmd = SSD1306_COMMAND_STREAM;
  int status = i2c_xfer_surrogate(chan, WRITE, addr, &cmd, 1, pCommands, len);
  assert(status == OK);

  return status;
}

 int ssd1306_send_data_stream(int chan, int addr, byte* pdata, int len)
{
    byte buf1 = SSD1306_DATA_STREAM;
    int status = i2c_xfer_surrogate(chan, WRITE, addr, &buf1, 1, pdata, len);
    assert(status == OK);

    return status;
}

 int ssd1306_send_command(int chan, int addr, int val)
{
    byte buf1 = SSD1306_COMMAND;
    byte buf2 = val;
    int status = i2c_xfer_surrogate(chan, WRITE, addr, &buf1, 1, &buf2, 1);
    assert(status == OK);

    return status;
}

 int ssd1306_send_data(int chan, int addr, int val)
{
    byte buf1 = SSD1306_DATA;
    byte buf2 = val;
    int status = i2c_xfer_surrogate(chan, WRITE, addr, &buf1, 1, &buf2, 1);
    assert(status == OK);

    return status;
}

int ssd1306_off(void)
{
    return ssd1306_send_command(I2C_EXTERNAL, SSD1306_ADDR, SSD1306_DISPLAY_OFF);
}

int ssd1306_on(void)
{
    return ssd1306_send_command(I2C_EXTERNAL, SSD1306_ADDR, SSD1306_DISPLAY_ON);
}

int ssd1306_normal_screen(void)
{
    return ssd1306_send_command(I2C_EXTERNAL, SSD1306_ADDR, SSD1306_DIS_NORMAL);
}

int ssd1306_inverse_screen(void)
{
    return ssd1306_send_command(I2C_EXTERNAL, SSD1306_ADDR, SSD1306_DIS_INVERSE);
}

int ssd1306_clear_screenX(void)
{
    int status;

    byte buffer[8] = {1|128,2|64,4|32,8|16,16|8,32|4,64|2,128|1};
    int i,j;

    for (i = 0; i < RAM_Y_END ; i++)
        for (j = 0; j < RAM_X_END; j++)
	{
            status = ssd1306_send_data_stream(I2C_EXTERNAL, SSD1306_ADDR, &buffer[0], 8);
            if (status != OK) return status;
        }

    return OK;
}

int ssd1306_clear_screen(void)
{
    int status;

    byte buffer[8] = {0,0,0,0,0,0,0,0};
    int i,j;

    for (i = 0; i < RAM_Y_END ; i++)
        for (j = 0; j < RAM_X_END; j++)
	{
            status = ssd1306_send_data_stream(I2C_EXTERNAL, SSD1306_ADDR, &buffer[0], 8);
            if (status != OK) return status;
        }

    return OK;
}

const byte INIT_SSD1306_STREAM[] = {
   SSD1306_DISPLAY_OFF,                                         // 0xAE = Set Display OFF
   SSD1306_SET_MUX_RATIO, MUX_VAL,                                   // 0xA8 - 64MUX for 128 x 64 version
                                                                  //      - 32MUX for 128 x 32 version
   SSD1306_MEMORY_ADDR_MODE, 0x00,                              // 0x20 = Set Memory Addressing Mode
                                                                  // 0x00 - Horizontal Addressing Mode
                                                                  // 0x01 - Vertical Addressing Mode
                                                                  // 0x02 - Page Addressing Mode (RESET)
   SSD1306_SET_COLUMN_ADDR, START_COLUMN_ADDR, END_COLUMN_ADDR, // 0x21 = Set Column Address, 0 - 127
   SSD1306_SET_PAGE_ADDR, START_PAGE_ADDR, END_PAGE_ADDR,       // 0x22 = Set Page Address, 0 - 7
   SSD1306_SET_START_LINE,                                      // 0x40
   SSD1306_DISPLAY_OFFSET, 0x00,                                // 0xD3
   SSD1306_SEG_REMAP_OP,                                        // 0xA0 / remap 0xA1
   SSD1306_COM_SCAN_DIR_OP,                                     // 0xC0 / remap 0xC8
   SSD1306_COM_PIN_CONF, PINCONF_VAL,                                  // 0xDA, 0x12 - Disable COM Left/Right remap, Alternative COM pin configuration
                                                                  //       0x12 - for 128 x 64 version
                                                                  //       0x02 - for 128 x 32 version
   SSD1306_SET_CONTRAST, 0x7F,                                  // 0x81, 0x7F - reset value (max 0xFF)
   SSD1306_DIS_ENT_DISP_ON,                                     // 0xA4
   SSD1306_DIS_NORMAL,                                          // 0xA6
   SSD1306_SET_OSC_FREQ, 0x80,                                  // 0xD5, 0x80 => D=1; DCLK = Fosc / D <=> DCLK = Fosc
   SSD1306_SET_PRECHARGE, 0xc2,                                 // 0xD9, higher value less blinking
                                                                  // 0xC2, 1st phase = 2 DCLK,  2nd phase = 13 DCLK
   SSD1306_VCOM_DESELECT, 0x20,                                 // Set V COMH Deselect, reset value 0x22 = 0,77xUcc
   SSD1306_SET_CHAR_REG, 0x14,                                  // 0x8D, Enable charge pump during display on
   SSD1306_DISPLAY_ON                                           // 0xAF = Set Display ON
};

/*
Patterned on accel.c of x18-level as we can't probe before tasks running
unless we write a separate pre-task TWI to allow probe and setup
hence name xxx_start() rather than xxx_init().

Given the heavy weigth of context switches needed to interact with the ssd1306
there would be no real harm in adding a driver wrapper.

*/

int ssd1306_start(void)
{
  int status;

  byte *pCommands = (byte*) INIT_SSD1306_STREAM;
#if 0
  status = i2c_probe(I2C_EXTERNAL, SSD1306_ADDR);
  if (status != OK) return status;
#endif
  status = ssd1306_send_command_stream(I2C_EXTERNAL, SSD1306_ADDR, pCommands, sizeof(INIT_SSD1306_STREAM) );
  return status;
}

static int ssd1306_set_window(byte x1, byte x2, byte y1, byte y2)
{
    int status;
    byte window_buffer[6] = {SSD1306_SET_COLUMN_ADDR, x1, x2,
                             SSD1306_SET_PAGE_ADDR,   y1, y2};

    status = ssd1306_send_command_stream(I2C_EXTERNAL, SSD1306_ADDR, window_buffer, sizeof(window_buffer));
    assert(status == OK);

    _indexCol = x1;
    _indexPage = y1;

    return status;
}

int ssd1306_set_position(byte x, byte y)
{
   return ssd1306_set_window(x, END_COLUMN_ADDR, y, END_PAGE_ADDR);
}

static int ssd1306_update_position(byte x, byte p)
{
   int status;

   if (x > END_COLUMN_ADDR) {
      if (p < END_PAGE_ADDR) {
         _indexCol = 0;
         _indexPage++;
         status = ssd1306_set_position(_indexCol, _indexPage);
         if (status != OK) return status;
      }
      else
         return SSD1306_ERROR; //last page reached
   }

   return OK;
}

int ssd1306_draw_character(char ch)
{
    int status;
    byte* pdata = (byte*)&FONTS[ch-32][0];

    status = ssd1306_update_position(_indexCol + CHARS_COLS_LENGTH, _indexPage);
    if (status != OK) return status;

    status = ssd1306_send_data_stream(I2C_EXTERNAL, SSD1306_ADDR, pdata, CHARS_COLS_LENGTH);
    if (status != OK) return status;
    _indexCol += CHARS_COLS_LENGTH;

    status = ssd1306_send_data(I2C_EXTERNAL, SSD1306_ADDR, 0);

    _indexCol++;

    return status;
}

int ssd1306_draw_string(char *str)
{
   int status = OK;

   while ((*str != '\0') && (status == OK))
      status = ssd1306_draw_character(*str++);

   return status;
}


