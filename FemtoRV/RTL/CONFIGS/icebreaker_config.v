// Default femtosoc configuration file for IceStick

`define NRV_NEGATIVE_RESET
/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS      // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART      // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1351   // Mapped IO, 128x128x64K OLed screen
`define NRV_IO_MAX7219   // Mapped IO, 8x8 led matrix
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Can be used with MINIRV32 to run code from SPI flash.

/************************* Frequency ********************************************************************************/

`define NRV_FREQ 40      // Frequency in MHz. Recomm: 20 MHz   Overclocking: 35 MHz

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

// Using the 128 kbytes of single-ported RAM of the ice40-up5k
// Note: cannot initialize it from .hex file, need to run from SPI Flash
`define ICE40UP5K_SPRAM
`define NRV_RAM 131072 

// (other option, the 12 kbytes of BRAM, this one can be initialized from .hex file).
//`define NRV_RAM 12288

/************************* Processor configuration ******************************************************************/

`define NRV_FEMTORV32_ELECTRON
`define NRV_COUNTER_WIDTH  24
`define NRV_RV32M // Tell the build system that we support RV32M

/************************* Advanced processor configuration *********************************************************/

`define NRV_RESET_ADDR 32'h00820000 // Jump execution to SPI Flash (800000h, +128k(20000h) for FPGA bitstream)
`define NRV_RUN_FROM_SPI_FLASH      // Do not 'readmemh()' firmware from '.hex' file

`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (only if you use your own firmware, libfemtorv32 depends on it)

/******************************************************************************************************************/

`define NRV_CONFIGURED
