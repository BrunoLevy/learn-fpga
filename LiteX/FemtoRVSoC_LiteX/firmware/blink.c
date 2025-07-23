#include <generated/csr.h>
#include <generated/soc.h>
#include <libbase/uart.h>
#include <libbase/time.h>

void main() {
    uart_init();

    while (1) {
        leds_out_write(0b001);  // Red
        msleep(500);
        leds_out_write(0b010);  // Green
        msleep(500);
        leds_out_write(0b100);  // Blue
        msleep(500);
    }
}
