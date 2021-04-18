// Default femtosoc configuration file for ULX3S

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS        // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART        // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1331     // Mapped IO, 96x64x64K OLed screen
//`define NRV_IO_SSD1351     // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX7219   // Mapped IO, 8x8 led matrix
`define NRV_IO_SDCARD      // Mapped IO, SPI SDCARD
`define NRV_IO_BUTTONS     // Mapped IO, buttons
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Use with MINIRV32 to run code from SPI flash.
`define NRV_IO_FGA // Femto Graphic Adapter (ULX3S only)

/************************* Frequency ********************************************************************************/

`define NRV_FREQ 85            // Frequency in MHz. Recomm: 50 MHz   Overclocking: 80-100 MHz (HX1K, ECP5)
`define NRV_FEMTORV32_ELECTRON // RV32IM, barrel shifter
`define NRV_RESET_ADDR 0       // The address the processor jumps to on reset 
`define NRV_RV32M              // Tell the build system that we support RV32M

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

//`define NRV_RAM 393216 // bigger config for ULX3S
`define NRV_RAM 262144 // default for ULX3S

/************************* Advanced processor configuration *********************************************************/

`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (only if you use your own firmware, libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
