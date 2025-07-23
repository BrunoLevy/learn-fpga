// riscv_logo.c
#include <stdint.h>

#define UART_BASE 0x82001000

void uart_putchar(char c) {
    while (*(volatile uint32_t *)(UART_BASE + 4)); // Wait until UART ready
    *(volatile uint32_t *)UART_BASE = c;           // Write char
}

void uart_putstr(const char *s) {
    while (*s) uart_putchar(*s++);
}

void delay() {
    for (volatile int i = 0; i < 1000000; i++);
}

int main() {
    while (1) {
        uart_putstr("Hello VSD UART!\r\n");
        delay();
    }
}
