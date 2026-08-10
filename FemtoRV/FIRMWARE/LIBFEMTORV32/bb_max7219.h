#ifndef _BB_MAX7219_H__
#define _BB_MAX7219_H__
#include <bb_spi.h>

#define GPIO_SCK  0
#define GPIO_SS   1
#define GPIO_MOSI 2

#define BB_CLKusDELAY 10 //uS delay

void BB_MAX7219(uint8_t reg, int8_t data);
void BB_MAX7219_init(void);
#endif
