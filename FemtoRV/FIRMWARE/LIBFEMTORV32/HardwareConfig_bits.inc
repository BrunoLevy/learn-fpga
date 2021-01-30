
# Constants for memory-mapped IO registers.                      
# Automatically extracted from RTL/DEVICES/HardwareConfig_bits.v 

.equ IO_LEDS_bit, 0
.equ IO_UART_DAT_bit, 1
.equ IO_UART_CNTL_bit, 2
.equ IO_SSD1351_CNTL_bit, 3
.equ IO_SSD1351_CMD_bit, 4
.equ IO_SSD1351_DAT_bit, 5
.equ IO_SSD1351_DAT16_bit, 6
.equ IO_MAX7219_DAT_bit, 7
.equ IO_SDCARD_bit, 8
.equ IO_BUTTONS_bit, 9
.equ IO_FGA_CNTL_bit, 10
.equ IO_FGA_DAT_bit, 11
.equ IO_HW_CONFIG_RAM_bit, 17
.equ IO_HW_CONFIG_DEVICES_bit, 18
.equ IO_HW_CONFIG_CPUINFO_bit, 19
.equ IO_MAPPED_SPI_FLASH_bit, 20

#################################################################
# IO_XXX = 1 << (IO_XXX_bit + 2)

.equ IO_LEDS, 4
.equ IO_UART_DAT, 8
.equ IO_UART_CNTL, 16
.equ IO_SSD1351_CNTL, 32
.equ IO_SSD1351_CMD, 64
.equ IO_SSD1351_DAT, 128
.equ IO_SSD1351_DAT16, 256
.equ IO_MAX7219_DAT, 512
.equ IO_SDCARD, 1024
.equ IO_BUTTONS, 2048
.equ IO_FGA_CNTL, 4096
.equ IO_FGA_DAT, 8192
.equ IO_HW_CONFIG_RAM, 524288
.equ IO_HW_CONFIG_DEVICES, 1048576
.equ IO_HW_CONFIG_CPUINFO, 2097152
.equ IO_MAPPED_SPI_FLASH, 4194304
