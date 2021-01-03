// We got a total of 20 bits for 1-hot addressing of IO registers.

localparam IO_LEDS_bit              = 0;  // RW four leds
localparam IO_UART_DAT_bit          = 1;  // RW write: data to send (8 bits) read: received data (8 bits)
localparam IO_UART_CNTL_bit         = 2;  // R  status. bit 8: valid read data. bit 9: busy sending
localparam IO_SSD1351_CNTL_bit      = 3;  // W  Oled display control
localparam IO_SSD1351_CMD_bit       = 4;  // W  Oled display commands (8 bits)
localparam IO_SSD1351_DAT_bit       = 5;  // W  Oled display data (8 bits)
localparam IO_MAX7219_DAT_bit       = 6;  // W  led matrix data (16 bits)
localparam IO_SPI_FLASH_bit         = 7;  // RW write: SPI address (24 bits) read: data (1 byte) 
localparam IO_SDCARD_bit            = 8;  // RW write: bit 0: mosi  bit 1: clk   bit 2: csn read: miso
localparam IO_BUTTONS_bit           = 9;  // R  buttons state
localparam IO_FGA_CNTL_bit          = 10; // RW RESERVED
localparam IO_FGA_CMD_bit           = 11; // W  RESERVED

// The three constant hardware config registers, using the three last bits of IO address space
localparam IO_HW_CONFIG_RAM_bit     = 17;  // R  total quantity of RAM, in bytes
localparam IO_HW_CONFIG_DEVICES_bit = 18;  // R  configured devices
localparam IO_HW_CONFIG_CPUINFO_bit = 19;  // R  CPU information CPL(6) FREQ(10) RESERVED(16)

// These devices do not have hardware registers. Just a bit set in IO_HW_CONFIG_DEVICES
localparam IO_MAPPED_SPI_FLASH_bit  = 20;  // no register (just there to indicate presence)


