
# Constants for memory-mapped IO registers.                      
# Automatically extracted from RTL/DEVICES/HardwareConfig_bits.v 

.equ IO_LEDs_bit, 0
.equ IO_SSD1351_CNTL_bit, 1
.equ IO_SSD1351_CMD_bit, 2
.equ IO_SSD1351_DAT_bit, 3
.equ IO_UART_DAT_bit, 5
.equ IO_UART_CNTL_bit, 11
.equ IO_MAX7219_DAT_bit, 7
.equ IO_SPI_FLASH_bit, 8
.equ IO_SDCARD_bit, 9
.equ IO_BUTTONS_bit, 10
.equ IO_MAPPED_SPI_FLASH_bit, 15
.equ IO_HW_CONFIG_RAM_bit, 6
.equ IO_HW_CONFIG_DEVICES_FREQ_bit, 4

#################################################################
# IO_XXX = 1 << (IO_XXX_bit + 2)

.equ IO_LEDS, 4
.equ IO_SSD1351_CNTL, 8
.equ IO_SSD1351_CMD, 16
.equ IO_SSD1351_DAT, 32
.equ IO_UART_DAT, 128
.equ IO_UART_CNTL, 8192
.equ IO_MAX7219_DAT, 512
.equ IO_SPI_FLASH, 1024
.equ IO_SDCARD, 2048
.equ IO_BUTTONS, 4096
.equ IO_MAPPED_SPI_FLASH, 131072
.equ IO_HW_CONFIG_RAM, 256
.equ IO_HW_CONFIG_DEVICES_FREQ, 64
