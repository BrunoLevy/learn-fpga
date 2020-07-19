#include <femtorv32.h>

#define MOSI_MASK 1
#define CLK_MASK  2
#define CSN_MASK  4

int spi_state = CSN_MASK;

inline void CS_H() {
    spi_state |= CSN_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline void CS_L() {
    spi_state &= ~CSN_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline void CK_H() {
    spi_state |= CLK_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline void CK_L() {
    spi_state &= ~CLK_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline void MOSI_H() {
    spi_state |= MOSI_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline void MOSI_L() {
    spi_state &= ~MOSI_MASK;
    IO_OUT(IO_SPI_SDCARD, spi_state);    
}

inline int MISO() {
    return IO_IN(IO_SPI_SDCARD);
}

inline void CLK_DELAY() {
    microwait(10);
}

inline void DLY_US(int t) {
    microwait(t);
}

void spi_send (uint8_t d) {
    if (d & 0x80) MOSI_H(); else MOSI_L();    /* bit7 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x40) MOSI_H(); else MOSI_L();    /* bit6 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x20) MOSI_H(); else MOSI_L();    /* bit5 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x10) MOSI_H(); else MOSI_L();    /* bit4 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x08) MOSI_H(); else MOSI_L();    /* bit3 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x04) MOSI_H(); else MOSI_L();    /* bit2 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x02) MOSI_H(); else MOSI_L();    /* bit1 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    if (d & 0x01) MOSI_H(); else MOSI_L();    /* bit0 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    DLY_US(10);
}

uint8_t spi_receive () {
    uint8_t r;
    MOSI_H();    /* Send 0xFF while receiving */
    r = 0;   if (MISO()) r++;    /* bit7 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit6 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit5 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit4 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit3 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit2 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit1 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    r <<= 1; if (MISO()) r++;    /* bit0 */
    CK_H(); CLK_DELAY(); CK_L(); CLK_DELAY();
    DLY_US(10);
    return r;
}

uint8_t spi_sendrecv(uint8_t cmd) {
    spi_send(cmd);
    return spi_receive();
}

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

static int sdhc_card = 0;

uint8_t sd_send_command(uint8_t cmd, uint32_t arg) {
    uint8_t response = 0xFF;
    uint8_t status;

    // If non-SDHC card, use byte addressing rather than block (512) addressing
    if(!sdhc_card) {
        switch (cmd) {
            case CMD17_READ_SINGLE_BLOCK:
            case CMD24_WRITE_SINGLE_BLOCK:
            case CMD32_ERASE_WR_BLK_START:
            case CMD33_ERASE_WR_BLK_END:
		arg *= 512;
		break;
        }
    }
    
    spi_send(cmd | CMD_START_BITS);
    spi_send((arg >> 24));
    spi_send((arg >> 16));
    spi_send((arg >> 8));
    spi_send((arg >> 0));

    // CRC required for CMD8 (0x87) & CMD0 (0x95) - default to CMD0
    spi_send((cmd == CMD8_SEND_IF_COND) ? CMD8_CRC : CMD0_CRC);

    // Wait for response (i.e MISO not held high)
    int count = 0;
    while((response = spi_receive()) == 0xff) {
	if(count > 500) {
	    printf("> 500 tries\n");
            break;
	}
	++count;   
    }

    // CMD58 has a R3 response
    if(cmd == CMD58_READ_OCR && response == 0x00) {
        // Check for SDHC card
        status = spi_receive();
        if(status & OCR_SHDC_FLAG) {
            sdhc_card = 1;
	} else {
            sdhc_card = 0;
	}

        // Ignore other response bytes for now
        spi_receive();
        spi_receive();
        spi_receive();
    }
    
    // Additional 8 clock cycles over SPI
    spi_send(0xFF);

    return response;
}

int sd_init() {
    int retries = 0;
    uint8_t response = 0xFF;
    uint8_t sd_version;
    delay(2);
    
    CS_H();
    MOSI_H();
    DLY_US(100);
    for(int i=0; i<200; ++i) {
	CK_H();
	CLK_DELAY();
	CK_L();
	CLK_DELAY();
    }
    DLY_US(100);
    
    CS_L();
    DLY_US(100);

    retries = 0;
    do {
	printf("Try %d\n", retries);
        response = sd_send_command(CMD0_GO_IDLE_STATE, 0);
	printf("response = %d\n", response);
        if(retries++ > 8) {
            CS_H();
            return -1;
        }
    } 
    while(response != CMD_OK);
    printf("OK1\n");

    spi_send(0xff);
    spi_send(0xff);

    // Set to default to compliance with SD spec 2.x
    sd_version = 2; 

    // Send CMD8 to check for SD Ver2.00 or later card
    retries = 0;
    do {
        // Request 3.3V (with check pattern)
        response = sd_send_command(CMD8_SEND_IF_COND, CMD8_3V3_MODE_ARG);
        if(retries++ > 8) {
            // No response then assume card is V1.x spec compatible
            sd_version = 1;
            break;
        }
    } while(response != CMD_OK);
    printf("OK2  version = %d\n",sd_version);

    
    return 0;
}

int main() {
    femtosoc_tty_init();
    sd_init();
    
    
    /*
    spi_send(0x40);
    spi_send(0x0);
    spi_send(0x0);
    spi_send(0x0);
    spi_send(0x0);
    spi_send(0x95);
    for(int i=0; i<10; ++i) {
	printf("%d\n", spi_receive());
    }
    */
    
    return 0;
}
