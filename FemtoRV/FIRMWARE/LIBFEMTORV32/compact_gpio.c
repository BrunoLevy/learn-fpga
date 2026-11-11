#include <compact_gpio.h>

/*combined shadow register to keep LUT count down*/
compact_gpio_write_shadow_t gpio_shadow_write_register;

/*CONFIGURE DIRECTION*/
void gpio_set_all_modes(uint32_t dir_mode_pattern) {
     gpio_shadow_write_register.ctrl_config = (uint8_t)dir_mode_pattern;
     GPIO_OUT(IO_GPIO_CONFIG, ((uint32_t)gpio_shadow_write_register.latch));
}

void gpio_set_pin_mode(uint32_t pin, uint32_t dir_mode) {
    if(dir_mode) {
        gpio_shadow_write_register.ctrl_config |= (uint8_t)(1<< pin);
    } else {
        gpio_shadow_write_register.ctrl_config &= (uint8_t)~(1 << pin);
    }
    GPIO_OUT(IO_GPIO_CONFIG, ((uint32_t)gpio_shadow_write_register.latch));
}

/*WRITE LEVEL*/
void gpio_set_all_pins(uint32_t levels_pattern) {
    gpio_shadow_write_register.output_levels = (uint8_t)levels_pattern;
    GPIO_OUT(IO_GPIO_WRITE, ((uint32_t)gpio_shadow_write_register.latch));
}

void gpio_set_pin(uint32_t pin, uint32_t level) {
    if(level) {
         gpio_shadow_write_register.output_levels |= (uint8_t)(1 << pin);
    } else {
         gpio_shadow_write_register.output_levels &= (uint8_t)~(1 << pin);
    }
    GPIO_OUT(IO_GPIO_WRITE, ((uint32_t)gpio_shadow_write_register.latch));
}

/*READ LEVEL*/
volatile uint32_t gpio_get_all_pins(void) {
    return GPIO_IN(IO_GPIO_READ);
}

volatile uint32_t gpio_get_pin(uint32_t pin) {
    return GPIO_IN(IO_GPIO_READ) & (1 << pin);
}

/*INIT SHADOW REGISTER AND HARDWARE*/
void gpio_init(void) {
    gpio_shadow_write_register.latch = 0;
    GPIO_OUT(IO_GPIO_CONFIG, (uint32_t)gpio_shadow_write_register.latch);
}

/*alternate function to normal gpio_init()*/
void gpio_force(uint8_t force_dir_mode_pattern, uint8_t force_levels_pattern) {
    gpio_shadow_write_register.ctrl_config = (uint8_t)force_dir_mode_pattern;
    gpio_shadow_write_register.output_levels = (uint8_t)force_levels_pattern;
    //IO_GPIO_CONFIG and IO_GPIO_WRITE are decoration
    GPIO_OUT(IO_GPIO_CONFIG, ((uint32_t)gpio_shadow_write_register.latch));

}

//#define GPIO_SDA COMPACT_GPIO_PIN(0)
//#define GPIO_SCL COMPACT_GPIO_PIN(1)

/*
void gpio_test(void) {
   //gpio_shadow_write_register.latch = 0;
   gpio_shadow_write_register.output_levels = 0x21;
   gpio_shadow_write_register.ctrl_config = 0x43; 
//    GPIO_OUT(IO_GPIO_CONFIG, (uint32_t)gpio_shadow_write_register.latch);
}
*/
/*
typedef uint32_t BOOL;
#define TRUE 1
#define FALSE 0

void digitalWrite(int pin, BOOL level)
{
   //add a test to see if we need to change direction
   gpio_set_pin_mode(pin, GPIO_MODE_OUTPUT);
   printf("Gp%dl%d %x\n", pin, (level ? GPIO_HI : GPIO_LO), gpio_shadow_write_register.latch);
   gpio_set_pin(pin, ((level == TRUE) ? GPIO_HI : GPIO_LO));
   printf("Gp%dl%d %x\n", pin, ((level == TRUE) ? GPIO_HI : GPIO_LO), gpio_shadow_write_register.latch); 
}

BOOL digitalRead(int pin)
{
   //add a test to see if we need to change direction
   gpio_set_pin_mode(pin, GPIO_MODE_INPUT);
   return (gpio_get_pin(pin) ? TRUE : FALSE);
}
*/

