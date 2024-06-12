// Default femtosoc configuration file for Tangnano20k

/*** Devices ******************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 = errors)
`define NRV_IO_UART          // Mapped IO, virtual UART (USB)
//`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
//`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix
//`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. 

/*** Processor configuration **************************************************/

`define NRV_FREQ 70          // Frequency in MHz

//         CORE                      RV32 subset    fmax validated-experimental
//
//`define NRV_FEMTORV32_QUARK       // RV32I          fmax = 80-110 MHz
//`define NRV_FEMTORV32_TACHYON     // RV32I          fmax = 100-135 MHz
//`define NRV_FEMTORV32_ELECTRON    // RV32IM         fmax = 70-80 MHz
//`define NRV_FEMTORV32_INTERMISSUM // RV32IM,   IRQ  fmax = 60-80 MHz
//`define NRV_FEMTORV32_GRACILIS    // RV32IMC,  IRQ  fmax = 60-80 MHz
`define NRV_FEMTORV32_PETITBATEAU   // RV32IMFC, IRQ  fmax = 50-80 MHz
//`define NRV_FEMTORV32_TESTDRIVE

`define NRV_RESET_ADDR 0       // The address the processor jumps to on reset 

/*** RAM (in bytes, needs to be a multiple of 4)*******************************/

`define NRV_RAM 313107 // XXX

/*** Advanced devices configuration *******************************************/

`define NRV_IO_HARDWARE_CONFIG // Hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/******************************************************************************/

`define NRV_NEGATIVE_RESET // reset button active low

`define NRV_CONFIGURED


