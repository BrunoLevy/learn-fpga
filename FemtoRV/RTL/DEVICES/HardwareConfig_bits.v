localparam IO_LEDS_bit         = 0; // (write) LEDs (4 LSBs)
   
localparam IO_SSD1351_CNTL_bit = 1; // (write) Oled display control
localparam IO_SSD1351_CMD_bit  = 2; // (write) Oled display commands (8 bits)
localparam IO_SSD1351_DAT_bit  = 3; // (write) Oled display data (8 bits)

localparam IO_UART_DAT_bit     = 5;  // (read/write) received data / data to send (8 bits)
localparam IO_UART_CNTL_bit    = 11; // (read) status. bit 8: valid read data. bit 9: busy sending

localparam IO_MAX7219_DAT_bit  = 7; // (write) led matrix data (16 bits)

localparam IO_SPI_FLASH_bit    = 8; // (write SPI address (24 bits) read: data (1 byte) 

                                // This one is a software "bit-banging" interface (TODO: hw support)
localparam IO_SDCARD_bit   = 9; // write: bit 0: mosi  bit 1: clk   bit 2: csn
                                // read:  bit 0: miso

localparam IO_BUTTONS_bit  = 10; // read: buttons state


localparam IO_MAPPED_SPI_FLASH_bit = 15; // Does not have any mapped reg. Bit is there for querying presence of device.

localparam IO_HW_CONFIG_RAM_bit          = 6;  // read: total quantity of RAM, in bytes

localparam IO_HW_CONFIG_DEVICES_FREQ_bit = 4;  // read: configured derives (16 LSB) and freq (16 MSB) 

