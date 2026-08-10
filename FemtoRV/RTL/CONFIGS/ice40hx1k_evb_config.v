// Default femtosoc configuration file for ICE40HX1K_EVB

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART          // Mapped IO, UART (USB) if jumpers soldered (also UEXT usb uart is a possibility but need to change pcf)
//`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
//`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix
`define NRV_IO_GPIOS          //disable NRV_IO_MAX7219 while using GPIO bit bang examples to accoumodate ICESTICK and ICE4PI PMOD
`define NRV_IO_GPIOS_WIDTH 6  //bitbang spi and i2c
`define NRV_IO_BUTTONS        // Mapped IO, BUT1 (note BUT2 used as RESET)
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Can be used to run code from SPI flash.

/************************* Processor configuration *******************************************************************/

`define NRV_FEMTORV32_QUARK

//`define NRV_FREQ 40
//I get an error if i try to use the pll that the synthesis tool says is there will have to read the data sheet carefully
//for now fixed 25MHz will have to do
//having read the datasheet there is no pll in this part
`define NRV_FREQ 25 //slower than it should be look at GEARDOWN to fix pll

`define NRV_RESET_ADDR 32'h00820000 // Jump execution to SPI Flash (800000h, +192k(30000h) for FPGA bitstream)
                                    // Maximum bitstream size is 136448 bytes and the firmware address is
				    // aligned to the block size 64KB, hence 192KB.
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts //no oled with shifts 96% lut utilisation, no oled without shifts 93%

//oled and no shifts 97% utilisation


/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 6144


/************************* Advanced devices configuration ***********************************************************/

`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file
`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
