#include <bb_spi.h>

bitbang_spi_port_t bb_spi;

void bitbang_spi_setup(uint8_t cs, uint8_t mosi, uint8_t miso, uint8_t sclk, uint32_t uDelay)
{
    bb_spi.cs = cs;
    bb_spi.mosi = mosi;
    bb_spi.miso = miso;
    bb_spi.sclk = sclk;
    bb_spi.uDelay = uDelay;
    
    gpio_set_pin_mode(cs, GPIO_MODE_OUTPUT);
    gpio_set_pin(cs, GPIO_HI); 

    microwait(uDelay);

    gpio_set_pin_mode(sclk, GPIO_MODE_OUTPUT);
    gpio_set_pin(sclk, GPIO_LO);          

    
    if (mosi != IGNORE_PIN) {
       gpio_set_pin_mode(mosi, GPIO_MODE_OUTPUT);
       gpio_set_pin(mosi, GPIO_LO);          
    }
 
    if (miso != IGNORE_PIN) {
        gpio_set_pin_mode(miso, GPIO_MODE_INPUT);
    }
}

uint8_t bitbang_spi_xfer8(uint8_t cargo)
{
   for (uint8_t bit_count = 0; bit_count < 8; bit_count++) 
   {
       if (bb_spi.mosi != IGNORE_PIN)
       {
          gpio_set_pin(bb_spi.mosi, ((cargo & 0x80) ? GPIO_HI : GPIO_LO));    
       }
       // finished with MS bit, get read to receive next bit      
       cargo <<= 1;
 
       // read MISO
       if (bb_spi.miso != IGNORE_PIN) { 
          cargo |= (gpio_get_pin(bb_spi.miso) != 0);
       }
       
       // clock hi
       //digitalWrite(bb_spi.sclk, TRUE);
        gpio_set_pin(bb_spi.sclk, GPIO_HI);          

       microwait(bb_spi.uDelay);
    
       //digitalWrite(bb_spi.sclk, FALSE);
       gpio_set_pin(bb_spi.sclk, GPIO_LO);                 
       // clock lo
       microwait(bb_spi.uDelay);
    } 
   
  return cargo;
  } 

