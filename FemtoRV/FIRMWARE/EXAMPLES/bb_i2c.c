//acknowledgement needs to go here
#include <femtorv32.h>
#include <femtoGL.h>
#include <bb_max7219_text.h>
#include <compact_gpio.h>
#include <stdbool.h>

//if oled has 64 rows rather than 32 rows
#define __DISP_64__

#define I2C_DELAY 1
#define  dly() microwait(I2C_DELAY);

uint8_t  GPIO_SDA = 1;
uint8_t  GPIO_SCL = 0;

#define SDA_INIT()    {gpio_set_pin_mode(GPIO_SDA, GPIO_MODE_INPUT); gpio_set_pin(GPIO_SDA, GPIO_LO);}
#define SCL_INIT()    {gpio_set_pin_mode(GPIO_SCL, GPIO_MODE_INPUT); gpio_set_pin(GPIO_SCL, GPIO_LO);}

#define SDA_ON()      gpio_set_pin_mode(GPIO_SDA, GPIO_MODE_INPUT)
#define SDA_OFF()     {gpio_set_pin_mode(GPIO_SDA, GPIO_MODE_OUTPUT); gpio_set_pin(GPIO_SDA, GPIO_LO);}
#define SCL_ON()      gpio_set_pin_mode(GPIO_SCL, GPIO_MODE_INPUT)
#define SCL_OFF()     {gpio_set_pin_mode(GPIO_SCL, GPIO_MODE_OUTPUT); gpio_set_pin(GPIO_SCL, GPIO_LO);}

#define SDA_READ()    gpio_get_pin(GPIO_SDA)  //assume already in GPIO_INPUT_MODE due to preceeding gpio_set_pin_mode()
#define SCL_READ()    gpio_get_pin(GPIO_SCL)  //assume already in GPIO_INPUT_MODE due to preceeding gpio_set_pin_mode()

#define I2C_READ    0x01
#define I2C_WRITE   0x00



/*  i2c start sequence */
void i2c_Start(void){
    SDA_ON();
    dly();
    SCL_ON();
    dly();
    SDA_OFF();
    dly();
    SCL_OFF();
    dly();
}

/*  i2c stop sequence */
void i2c_Stop(void){
    SDA_OFF();
    dly();
    SCL_ON();
    dly();
    SDA_ON();
    dly();
}

/* Transmit 8 bit data to slave */
bool i2c_Tx(uint8_t dat){

    for(uint8_t i=8; i; i--){
        if (dat & 0x80)
            SDA_ON();
        else
            SDA_OFF();
                    //(dat & 0x80) ? SDA_ON() : SDA_OFF(); //Mask for the eigth bit
        dat<<=1;  //Move
        dly();
        SCL_ON();
        dly();
        SCL_OFF();
        dly();
    }
    SDA_ON();
    SCL_ON();
    dly();
    bool ack = (SDA_READ() == 0) ? true : false;    // Acknowledge bit  TODO TEST VALUE RETURN FROM gpio_get_pin TODO
    SCL_OFF();
    return ack;
}



uint8_t i2c_Rx(bool ack){
    uint8_t dat = 0;
    SDA_ON();
    for( uint8_t i=0; i<8; i++){
        dat <<= 1;
        SCL_ON();
        dly();
        while(SCL_READ());  //clock stretching could lock up without timeout
        if (SDA_READ()) dat |=1;
        SCL_OFF();
        dly();
    }
    if (ack) SDA_OFF();
    SCL_ON();
    dly();
    SCL_OFF();
    SDA_ON();
    return(dat);
}
#if 0
//possibility untested
int16_t i2c_Rx_with_timeout(bool ack, uint32_t uS_timeout){
    uint64_t start_cycles = cycles();
    uint32_t timeout_cycles = FEMTORV32_FREQ * uS_timeout;
    uint8_t dat = 0;
    SDA_ON();
    for( uint8_t i=0; i<8; i++){
        dat <<= 1;
        SCL_ON();
        dly();
        do{
            if (cycles() - start_cycles >= timeout_cycles) {
               goto rx_timeout;
            }
        } while(SCL_READ());  //clock stretching with timeout in uSec range
        if (SDA_READ()) dat |=1;
        SCL_OFF();
        dly();
    }
    if (ack) SDA_OFF();
    SCL_ON();
    dly();
    SCL_OFF();
    SDA_ON();
    return (dat);
rx_timeout:
    if (dat<0){
        ic2_Stop();
        delay(5);
        i2c_Start();
        delay(5);
    }
    return(-1);
}
#endif

int8_t i2c_WriteBytes(uint8_t *pData, uint8_t len){
    uint8_t cargo;
    bool rc = true;
    uint8_t oldlen = len;

    while (len && (rc==true)){
        cargo = *pData++;
        rc = i2c_Tx(cargo);
        if (rc==true) len--;
    }
    return (rc==true) ? (oldlen - len) : 0;
}

void i2c_ReadBytes(uint8_t *pData, uint8_t len){
    while (len--){
        *pData++ = i2c_Rx(len==0);
    }
}

int i2c_xfer(int chan, int kind, int addr, uint8_t* p1, int len1, uint8_t* p2, int len2)
{
    bool rc;
    int howmany1 = 0;
    int howmany2 = 0;

    i2c_Start();
    addr <<= 1;
    if (kind == I2C_READ) addr++;
    rc = i2c_Tx(addr);
    if (!rc) {
       i2c_Stop();
       return 0;
    }

    if (kind == I2C_WRITE) {
        howmany1 = i2c_WriteBytes(p1, len1);
        if (howmany1 == len1) {
            if ((len2 > 0) && p2)
                howmany2 = i2c_WriteBytes(p2, len2);
                if (howmany2 != len2)
                {
                    i2c_Stop();
                    return 0;
                }
        }
    }
    else if (kind == I2C_READ) {
        howmany1 = i2c_WriteBytes(p1, len1);
        if (howmany1 == len1) {
            if ((len2 > 0) && p2)
                /*howmany2 = */i2c_ReadBytes(p2, len2);
                /*if (howmany2 != len2)
                {
                    i2c_Stop();
                    return 0;
                }*/
        }
    }

    i2c_Stop();
    return 1;
}


int i2c_probe(int chan, int addr)
{
    uint8_t buf = 0;
    return i2c_xfer(chan, I2C_WRITE, addr, &buf, 1, NULL, 0);
}

//add i2c_read and i2c_write functions

void i2c_init(uint8_t sda, uint8_t scl){
    GPIO_SDA = sda;
    GPIO_SCL = scl;

    SDA_INIT();
    SCL_INIT();
}




#include "ssd1306.h"




unsigned short int _indexCol = START_COLUMN_ADDR;
unsigned short int _indexPage = START_PAGE_ADDR;


 int ssd1306_send_command_stream(int chan, int addr, byte* pCommands, int len)
{
  byte cmd = SSD1306_COMMAND_STREAM;
  int status = i2c_xfer(chan, I2C_WRITE, addr, &cmd, 1, pCommands, len);
  //assert(status == OK);

  return status;
}

 int ssd1306_send_data_stream(int chan, int addr, byte* pdata, int len)
{
    byte buf1 = SSD1306_DATA_STREAM;
    int status = i2c_xfer(chan, I2C_WRITE, addr, &buf1, 1, pdata, len);
    //assert(status == OK);

    return status;
}

 int ssd1306_send_command(int chan, int addr, int val)
{
    byte buf1 = SSD1306_COMMAND;
    byte buf2 = val;
    int status = i2c_xfer(chan, I2C_WRITE, addr, &buf1, 1, &buf2, 1);
    //assert(status == OK);

    return status;
}

 int ssd1306_send_data(int chan, int addr, int val)
{
    byte buf1 = SSD1306_DATA;
    byte buf2 = val;
    int status = i2c_xfer(chan, I2C_WRITE, addr, &buf1, 1, &buf2, 1);
    //assert(status == OK);

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

#ifdef __DISP_64__
#define RAM_Y_END_PROBLEM 1
#else
#define RAM_Y_END_PROBLEM RAM_Y_END
#endif

int ssd1306_clear_screenX(void)
{
    int status;

    byte buffer[8] = {1|128,2|64,4|32,8|16,16|8,32|4,64|2,128|1};
    int i,j;

    for (i = 0; i < RAM_Y_END_PROBLEM ; i++)
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

    for (i = 0; i < RAM_Y_END_PROBLEM ; i++)
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

int ssd1306_start(void)
{
  int status;

  byte *pCommands = (byte*) INIT_SSD1306_STREAM;
#if 1
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
    //assert(status == OK);

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


void tester(void)
{
    ssd1306_start();
    ssd1306_clear_screenX();

    ssd1306_set_position(0,0);
    ssd1306_draw_string("abcdefg!");
}

void tester2(void)
{
    ssd1306_set_position(0,0);
    ssd1306_draw_string("ABCDEFG!");
}

void tester3(void)
{
    ssd1306_set_position(0,0);
    ssd1306_draw_string(".......!");
}

void tester4(void)
{
    ssd1306_set_position(0,1);
    ssd1306_draw_string("Screen saver");
    ssd1306_clear_screen();

    printf("OLED Screen saver\n");
}


//same as probe
uint8_t detect(uint8_t addr)
{
    i2c_Start();
    uint8_t res = i2c_Tx((addr<<1)|I2C_WRITE);
    i2c_Stop();
    return res;
}


//#include "cg_pinout_uextoledtester.h"
//contents of cg_pinout_uextoledtester.h
//configured for UEXT i2c+spi
#define CG_SDA  4
#define CG_SCL  5

#define SIMPLE_RTC_ADDR        0x68

void dummy_linkme(void)
{
   GL_set_font(&Font8x8);
}

int main(){
    int rc;

    gpio_init();
    i2c_init(CG_SDA, CG_SCL);
//could do with a software register to indicate presence of compact_gpio peripherals
//so that initialisation can be done early and with out having to do anything explicit
//in the application code
//need to design a flexible scheme for this if there is any interest
#if 1
    BB_MAX7219_tty_init();
#else
    GL_tty_init(GL_MODE_OLED);
    GL_set_font(&Font8x16);
    GL_clear();
#endif
    printf("TEST BB_I2C\n");
    rc = detect(SIMPLE_RTC_ADDR);
    if (rc) printf("RTC\n");
    rc = detect(SSD1306_ADDR);
    if (rc) printf("1306OLED\n");

   tester();
   ssd1306_clear_screen();

    int loop = 10;
    while(loop--){
        printf("%d", loop);
        tester2();
        tester3();
    }

    //screen saver to protect oled pixels
    tester4();

    while(1) {
       printf("RESET to restart\n");
    }

   exit(0);
}
