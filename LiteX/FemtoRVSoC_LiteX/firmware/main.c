#define UART_TX_ADDR ((volatile uint32_t*)0x82000000)
#define UART_DELAY() for (volatile int i = 0; i < 500; i++) {}

void uart_send(char c) {
    // Start bit (LOW)
    *UART_TX_ADDR = 0;
    UART_DELAY();

    // Data bits (LSB first)
    for (int i = 0; i < 8; i++) {
        *UART_TX_ADDR = (c >> i) & 1;
        UART_DELAY();
    }

    // Stop bit (HIGH)
    *UART_TX_ADDR = 1;
    UART_DELAY();
}

int main() {
    *UART_TX_ADDR = 1; // Idle state
    UART_DELAY();

    while (1) {
        uart_send('H');
        uart_send('i');
        uart_send('\n');
        for (volatile int i = 0; i < 100000; i++); // delay between prints
    }
}
