// Default femtosoc configuration file for ICE40HX8K-EVB

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART          // Mapped IO, virtual UART (USB)
//`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
//`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Can be used to run code from SPI flash.

/************************* Processor configuration *******************************************************************/

`define NRV_FEMTORV32_QUARK
`define NRV_FREQ 40
`define NRV_RESET_ADDR 32'h00830000 // Jump execution to SPI Flash (800000h, +192k(30000h) for FPGA bitstream)
                                    // Maximum bitstream size is 136448 bytes and the firmware address is
				    // aligned to the block size 64KB, hence 192KB.
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts


/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 10240


/************************* Advanced devices configuration ***********************************************************/

`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file
`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
