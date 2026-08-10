#include <bb_max7219.h>

void BB_MAX7219(uint8_t reg, int8_t data)
{
    gpio_set_pin(GPIO_SS, GPIO_LO);                 
    microwait(BB_CLKusDELAY);

    (void)bitbang_spi_xfer8(reg);
    (void)bitbang_spi_xfer8(data);
    
    gpio_set_pin(GPIO_SS, GPIO_HI);                 
    microwait(BB_CLKusDELAY);
}

void BB_MAX7219_init(void)
{
    //maybe check if already claimed
    //gpio_init();
   
    bitbang_spi_setup(GPIO_SS, GPIO_MOSI, IGNORE_PIN, GPIO_SCK, BB_CLKusDELAY);
    gpio_set_pin(GPIO_SS, GPIO_LO);                 
    microwait(BB_CLKusDELAY);
    
    BB_MAX7219(0x09, 0x00);  //0=no decode
    BB_MAX7219(0x0a, 0x02);  //brightness initially 0x0f
    BB_MAX7219(0x0b, 0x07);  //scan limit between 0 and 7
    BB_MAX7219(0x0c, 0x01);  //wakeup=1/shutdown
    BB_MAX7219(0x0f, 0x00);  //0=test mode off
}
