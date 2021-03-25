// Default femtosoc configuration file for IceStick

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_IRDA          // In IO_LEDS, support for the IRDA on the IceStick (WIP)
`define NRV_IO_UART          // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Use with MINIRV32 to run code from SPI flash.

/************************* Processor configuration *******************************************************************/

//`define NRV_MINIRV32 // Mini config, can run from SPI flash (mapped at 800000h).
`define NRV_MINIRV32_2 // Single-file mini config (Matthias Koch), can run from SPI flash (mapped at 800000h).

// Frequency in MHz
`ifdef NRV_MINIRV32_2
`define NRV_FREQ 40    // single-file mini config validated at 45 MHz.
`else
`define NRV_FREQ 66    // mini config validated at 63 MHz. Overclocked a bit. Note: LUT count may overflow.
`endif

`define NRV_RESET_ADDR 32'h00810000 // Jump execution to SPI Flash (800000h, +64k(10000h) for FPGA bitstream)

`define NRV_COUNTER_WIDTH 30 // for NRV_MINIRV32_2, optional cycles counter (but you'll need to deactivate UART)

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 6144           // default for ICESTICK (cannot do more !)

/************************* Advanced devices configuration ***********************************************************/

`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file
`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
