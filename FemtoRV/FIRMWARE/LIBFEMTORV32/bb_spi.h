#ifndef _BB_SPI_H__
#define _BB_SPI_H__
#include <compact_gpio.h>

uint8_t bitbang_spi_xfer8(uint8_t cargo) RV32_FASTCODE;
void bitbang_spi_setup(uint8_t cs, uint8_t mosi, uint8_t miso, uint8_t sclk, uint32_t uDelay);
uint8_t bitbang_spi_xfer8(uint8_t cargo);

//synchronize pin assignments with pin constraint file entries
//for instance bitbang 3 pin SPI interface to MAX7219
//#define GPIO_SCK  0
//#define GPIO_SS   1
//#define GPIO_MOSI 2
//#define GPIO_MISO GPIO_IGNORE_PIN

typedef struct bitbang_spi_port {
    uint8_t cs;
    uint8_t sclk;
    int8_t  mosi;
    int8_t  miso;
    uint32_t uDelay;
} bitbang_spi_port_t;

#endif
