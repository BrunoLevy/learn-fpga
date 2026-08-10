#ifndef _COMPACT_GPIO_H_
#define _COMPACT_GPIO_H_
#include <femtorv32.h>


//#define GPIO_IN(port)       (*(volatile uint32_t*)(IO_BASE + port) & 0x000000ff)
#define GPIO_IN(port)       (*(volatile uint32_t*)(IO_BASE + port)) //when not returing registered info from compact_gpio.v no need to mask
#define GPIO_OUT(port,val)  *(uint32_t*)(IO_BASE + port)=(val)
//#define LEDS(val)         IO_OUT(IO_LEDS,val)

#define IO_GPIO_CONFIG      IO_GPIOS 
#define IO_GPIO_WRITE       IO_GPIOS
#define IO_GPIO_READ        IO_GPIOS

//zero based pin index up to 8 pins
#define COMPACT_GPIO_PIN(n) n
#define IGNORE_PIN (-1)    //pass to setup function to disable use where applicable


union compact_gpio_write_shadow_tag
{
    uint32_t latch;
    struct {
        unsigned readback : 8;
        unsigned dont_care :8;
        unsigned ctrl_config : 8;
        unsigned output_levels : 8;
    };
};

typedef union compact_gpio_write_shadow_tag compact_gpio_write_shadow_t;

//define your gpio e.g.
//#define GPIO_SDA COMPACT_GPIO_PIN(0)
//#define GPIO_SCL COMPACT_GPIO_PIN(1)

//#define GPIO_PIN2 UNALLOCATED


/* GPIO address*/
#define GPIO_MODE_INPUT  0
#define GPIO_MODE_OUTPUT 1

#define GPIO_LO  0
#define GPIO_HI  1 

/* GPIO mode set functions*/
void gpio_set_all_mode_pins(uint32_t dir_mode_pattern) RV32_FASTCODE;
void gpio_set_pin_mode(uint32_t pin, uint32_t dir_mode) RV32_FASTCODE;

/* GPIO value set functions*/
void gpio_set_all_pins(uint32_t levels_pattern) RV32_FASTCODE;
void gpio_set_pin(uint32_t pin, uint32_t level) RV32_FASTCODE;

/* GPIO value get functions*/
uint32_t gpio_get_all_pins(void) RV32_FASTCODE;
uint32_t gpio_get_pin(uint32_t pin) RV32_FASTCODE;

/* GPIO init */
void gpio_init(void);
void gpio_force(uint8_t force_dir_mode_pattern, uint8_t force_levels_pattern);
#endif
