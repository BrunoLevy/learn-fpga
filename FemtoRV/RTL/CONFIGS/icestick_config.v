// Default femtosoc configuration file for IceStick

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_IRDA
`define NRV_IO_UART          // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Use with MINIRV32 to run code from SPI flash.

/************************* Frequency ********************************************************************************/

`define NRV_FREQ 66      // Frequency in MHz. Validated at 63 MHz. Overclocked a bit. Note: LUT count may overflow.

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 6144     // default for ICESTICK (cannot do more !)

/************************* Processor configuration ******************************************************************/

`define NRV_MINIRV32 // Mini config, can execute code stored in SPI flash from 1Mb offset (mapped to address 0x800000)

/************************* Advanced processor configuration *********************************************************/

`define NRV_RESET_ADDR 24'h810000  // Jump execution to SPI Flash (Mapped at 800000h, + leave 64k (10000h) for FPGA bitstream)

`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (only if you use your own firmware, libfemtorv32 depends on it)

/******************************************************************************************************************/
`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file

`define NRV_CONFIGURED
