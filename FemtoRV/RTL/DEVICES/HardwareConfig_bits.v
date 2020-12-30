localparam LEDs_bit         = 0; // (write) LEDs (4 LSBs)
   
localparam SSD1351_CNTL_bit = 1; // (write) Oled display control
localparam SSD1351_CMD_bit  = 2; // (write) Oled display commands (8 bits)
localparam SSD1351_DAT_bit  = 3; // (write) Oled display data (8 bits)

localparam UART_DAT_bit     = 5; // (read/write) received data / data to send (8 bits)

localparam MAX7219_DAT_bit  = 7; // (write) led matrix data (16 bits)

localparam SPI_FLASH_bit    = 8; // (write SPI address (24 bits) read: data (1 byte) 

                                 // This one is a software "bit-banging" interface (TODO: hw support)
localparam SPI_SDCARD_bit   = 9; // write: bit 0: mosi  bit 1: clk   bit 2: csn
                                 // read:  bit 0: miso

localparam BUTTONS_bit      = 10; // read: buttons state


localparam MAPPED_SPI_FLASH_bit = 15; // Does not have any mapped reg. Bit is there for querying presence of device.

localparam HW_CONFIG_RAM_bit          = 6;  // read: total quantity of RAM, in bytes

localparam HW_CONFIG_DEVICES_FREQ_bit = 4;  // read: configured derives (16 LSB) and freq (16 MSB) 

// configured devices
localparam NRV_DEVICES = 0
`ifdef NRV_IO_LEDS
   | (1 << LEDs_bit)			 
`endif			    
`ifdef NRV_IO_UART
   | (1 << UART_DAT_bit)			 
`endif			    
`ifdef NRV_IO_SSD1351
   | (1 << SSD1351_CNTL_bit) | (1 << SSD1351_CMD_bit) | (1 << SSD1351_DAT_bit)
`endif			    
`ifdef NRV_IO_MAX7219     
   | (1 << MAX7219_DAT_bit) 
`endif			    
`ifdef NRV_IO_SPI_FLASH
   | (1 << SPI_FLASH_bit) 			 
`endif			    
`ifdef NRV_IO_SPI_SDCARD
   | (1 << SPI_SDCARD_bit) 			 			 
`endif			    
`ifdef NRV_IO_BUTTONS
   | (1 << BUTTONS_bit) 			 			 			 
`endif 
`ifdef NRV_MAPPED_SPI_FLASH
   | (1 << MAPPED_SPI_FLASH_bit)		  
`endif			 
;

// CPL (Cycles per Loop)
// number of cycles for each
// iteration of:
// wait: sub a0, a0, a1
//       bgt a0, zero, wait
`ifdef NRV_MINIRV32
 `define NRV_CPL 9
`else
 `ifdef NRV_LATCH_ALU
  `define NRV_CPL 7
 `else
  `define NRV_CPL 6
 `endif
`endif
