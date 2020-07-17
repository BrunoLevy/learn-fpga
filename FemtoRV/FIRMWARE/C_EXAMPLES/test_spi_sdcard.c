/*
 * Trying to read contents from SDCard on the ULX3S
 */

/* SPI and SD driver from:
 * https://github.com/ultraembedded/minispartan6-audio/blob/master/src_c/drivers/spi/spi_lite.c
 * https://github.com/ultraembedded/minispartan6-audio/blob/master/src_c/drivers/sd/sd_spi.c
 *
 * TODO: change SPI driver to send one byte of command + one byte of data only.
 */


#include <femtorv32.h>

#define BUSY 256
 
uint8_t spi_sendrecv(uint8_t data) {
   int result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   IO_OUT(IO_SPI_FLASH, data);
   result = BUSY;
   while(result & BUSY) {
       result = IO_IN(IO_SPI_FLASH);
   }
   return result & 255;
}

void spi_readblock(uint8_t *ptr, int length) {
    int i;
    for (i=0;i<length;i++) {
        *ptr++ = spi_sendrecv(0xFF);
    }
}

void spi_writeblock(uint8_t *ptr, int length) {
    int i;
    for (i=0;i<length;i++) {
        spi_sendrecv(*ptr++);
    }
}

/*******************************************************************************/

#define CMD0_GO_IDLE_STATE              0
#define CMD1_SEND_OP_COND               1
#define CMD8_SEND_IF_COND               8
#define CMD17_READ_SINGLE_BLOCK         17
#define CMD24_WRITE_SINGLE_BLOCK        24
#define CMD32_ERASE_WR_BLK_START        32
#define CMD33_ERASE_WR_BLK_END          33
#define CMD38_ERASE                     38
#define ACMD41_SD_SEND_OP_COND          41
#define CMD55_APP_CMD                   55
#define CMD58_READ_OCR                  58

#define CMD_START_BITS                  0x40
#define CMD0_CRC                        0x95
#define CMD8_CRC                        0x87

#define OCR_SHDC_FLAG                   0x40
#define CMD_OK                          0x01

#define CMD8_3V3_MODE_ARG               0x1AA

#define ACMD41_HOST_SUPPORTS_SDHC       0x40000000

#define CMD_START_OF_BLOCK              0xFE
#define CMD_DATA_ACCEPTED               0x05

/*******************************************************************************/
static int _sdhc_card = 0;

static uint8_t _sd_send_command(uint8_t cmd, uint32_t arg)
{
    uint8_t response = 0xFF;
    uint8_t status;

    // If non-SDHC card, use byte addressing rather than block (512) addressing
    if(_sdhc_card == 0)
    {
        switch (cmd)
        {
            case CMD17_READ_SINGLE_BLOCK:
            case CMD24_WRITE_SINGLE_BLOCK:
            case CMD32_ERASE_WR_BLK_START:
            case CMD33_ERASE_WR_BLK_END:
                 arg *= 512;
                 break;
        }
    }

    // Send command
    spi_sendrecv(cmd | CMD_START_BITS);
    spi_sendrecv((arg >> 24));
    spi_sendrecv((arg >> 16));
    spi_sendrecv((arg >> 8));
    spi_sendrecv((arg >> 0));

    // CRC required for CMD8 (0x87) & CMD0 (0x95) - default to CMD0
    if(cmd == CMD8_SEND_IF_COND)
        spi_sendrecv(CMD8_CRC);
    else
        spi_sendrecv(CMD0_CRC);

    // Wait for response (i.e MISO not held high)
    int count = 0;
    while((response = spi_sendrecv(0xFF)) == 0xff)
    {
         if(count > 500)
            break;
         ++count;   
    }

    // CMD58 has a R3 response
    if(cmd == CMD58_READ_OCR && response == 0x00)
    {
        // Check for SDHC card
        status = spi_sendrecv(0xFF);
        if(status & OCR_SHDC_FLAG) 
            _sdhc_card = 1;
        else 
            _sdhc_card = 0;

        // Ignore other response bytes for now
        spi_sendrecv(0xFF);
        spi_sendrecv(0xFF);
        spi_sendrecv(0xFF);
    }

    // Additional 8 clock cycles over SPI
    spi_sendrecv(0xFF);

    return response;
}

/********************************************************************************/

int sd_init() {
    uint8_t response;
    uint8_t sd_version;
    int retries = 0;
    int i;

    // Initial delay to allow card to power-up
    delay(100);

 //   spi_cs(1);

    // Send 80 SPI clock pulses before performing init
    for(i=0;i<10;i++)
        spi_sendrecv(0xff);

  //  spi_cs(0);

    // Reset to idle state (CMD0)
    retries = 0;
    do
    {
        response = _sd_send_command(CMD0_GO_IDLE_STATE, 0);
        if(retries++ > 8)
        {
            spi_cs(1);
            return -1;
        }
    } 
    while(response != CMD_OK);

    spi_sendrecv(0xff);
    spi_sendrecv(0xff);

    // Set to default to compliance with SD spec 2.x
    sd_version = 2; 

    // Send CMD8 to check for SD Ver2.00 or later card
    retries = 0;
    do
    {
        // Request 3.3V (with check pattern)
        response = _sd_send_command(CMD8_SEND_IF_COND, CMD8_3V3_MODE_ARG);
        if(retries++ > 8)
        {
            // No response then assume card is V1.x spec compatible
            sd_version = 1;
            break;
        }
    }
    while(response != CMD_OK);

    retries = 0;
    do
    {
        // Send CMD55 (APP_CMD) to allow ACMD to be sent
        response = _sd_send_command(CMD55_APP_CMD,0);

        delay(100);

        // Inform attached card that SDHC support is enabled
        response = _sd_send_command(ACMD41_SD_SEND_OP_COND, ACMD41_HOST_SUPPORTS_SDHC);

        if(retries++ > 8)
        {
            spi_cs(1);
            return -2;
        }
    }
    while(response != 0x00);

    // Query card to see if it supports SDHC mode   
    if (sd_version == 2)
    {
        retries = 0;
        do
        {
            response = _sd_send_command(CMD58_READ_OCR, 0);
            if(retries++ > 8)
                break;
        }
        while(response != 0x00);
    }
    // Standard density only
    else
        _sdhc_card = 0;

    return 0;
}

int sd_init(void) {
    int retries = 0;

    // Peform SD init
    while (retries++ < 3)
    {
        if (_sd_init() == 0)
            return 0;

        delay(500);
    }

    return -1;
}


int get_spi_byte(int addr) {
   return 0;
}

void printb(int x) {
    for(int i=7; i>=0; i--) {
	putchar((x & (1 << i)) ? '1' : '0');
    }
}

int main() {
   int addr = 1024*1024;
   int data;
   GL_tty_init(); // uncomment if using OLED display instead of tty output.
   printf("Testing SPI flash\n");
   for(int i=0; i<14; ++i) {
      data = get_spi_byte(addr);
      printf("%x:",data);
      printb(data);
      putchar(':');
      putchar(data);
      printf("\n");
      ++addr;
   }
   return 0;
}
