// Default femtosoc configuration file for IceStick

/************************* Devices **********************************************************************************/

`define NRV_NEGATIVE_RESET

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART          // Mapped IO, virtual UART (USB)
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Can be used to run code from SPI flash.

/************************* Processor configuration *******************************************************************/

`define NRV_FEMTORV32_QUARK
`define NRV_FREQ 25                 // Validated at 25 MHz on pico ice
`define NRV_RESET_ADDR 32'h820000 // Jump execution to SPI Flash
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts
// tinyraytracer: 70 MHz, 17:30

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 6144 // default for ICESTICK (cannot do more !)


/************************* Advanced devices configuration ***********************************************************/

`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file
`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
