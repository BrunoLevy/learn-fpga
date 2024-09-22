/********************************************************************************************************************/
//N O T E icezero *Port to icezero is first go by a novice at fpga
//N O T E icezero *an example for icezero tachyon defines can be found below
//N O T E icezero *femtosoc configurations file info for IceZero {quark, tachyon and gracilis confirmed on silicon}
//N O T E icezero *with NRV_FREQ quark==40, tachyon==55, gracilis==24 other processors not tested yet
//icezero board clocking adopted according to output from synthesis tool
//N.B. `define NRV_FREQ 24 #for gracilis, but just room to go to 25 without overclock
//14kB BRAM, note TUTORIAL version left at 6kB BRAM to stay compatible with documentation and sources 
//icezero has 3 onboard LEDS not 5 these have legends D2, D3, D4
//Mapped IO, pcf aliased D2 for D5 as comments seen about error reporting on D5, but D3=D3 and D4=D4
//MAX_7219 pcf untested but we have losts of space compared to an icestick so left active
//tested with waveshare SSD1351
/********************************************************************************************************************/

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D2,D3,D4 (D5 is used to display errors) #will alias D2 for D5 because of error reporting nature
//`define NRV_IO_IRDA          // In IO_LEDS, support for the IRDA on the IceStick (WIP)
`define NRV_IO_UART          // Mapped IO, virtual UART #not (USB) /dev/ttyS0 on raspberry pi 40pin header
`define NRV_IO_SSD1351       // Mapped IO, 128x128x64K OLED screen
`define NRV_IO_MAX7219       // Mapped IO, 8x8 led matrix NOT TESTED BUT WE HAVE PLENTY OF SPACE TO LEAVE ACTIVE
`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Can be used to run code from SPI flash.

/************************* Processor configuration *******************************************************************/

/*
`define NRV_FEMTORV32_TACHYON       // "Tachyon" (carefully latched for max highfreq). Needs more space (remove MAX7219).
`define NRV_FREQ 60                 // Validated at 60 MHz on the IceStick. Can overclock to 80-95 MHz.
`define NRV_RESET_ADDR 32'h00820000 // Jump execution to SPI Flash (800000h, +128k(20000h) for FPGA bitstream)
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts
*/
// tinyraytracer: 90 MHz, stick was ??:??
//                95 MHz, stick was ??:??

/* trenz icezero tachyon example
//take care over NVR_RAM and NVR_RESET_ADDR as discordent with icestick examples
`define NRV_FEMTORV32_TACHYON       // "Tachyon" (carefully latched for max highfreq). Needs more space (remove MAX7219).
`define NRV_FREQ 55                 // Validated at 60 MHz on the IceStick. Can overclock to 80-95 MHz.
`define NRV_RESET_ADDR 32'h00830000 // Jump execution to SPI Flash (800000h, +128k(20000h) for FPGA bitstream)
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts
`define NRV_RAM 14336               // 6144 was default for ICESTICK we use all BRAMS available to us regfile=2k 14k=((2*8k) - regfile) 
*/


//`define NRV_FEMTORV32_QUARK
`define NRV_FEMTORV32_TACHYON // RV32I high freq
//`define NRV_FEMTORV32_QUARK_BICYCLE // RV32I 2 CPI
//`define NRV_FEMTORV32_ELECTRON // RV32IM
//`define NRV_FEMTORV32_GRACILIS // RV32IMC, IRQ  //tested on icezero from trenz at 24MHz, could do 25 without entering overclock territory
//`define NRV_FEMTORV32_PETITBATEAU


`define NRV_FREQ 55                 // Validated at 50 MHz on the IceStick. Can overclock to 70 MHz.
`define NRV_RESET_ADDR 32'h00830000 // Jump execution to SPI Flash (800000h, +192k(30000h) for FPGA bitstream on icezero)
`define NRV_COUNTER_WIDTH 24        // Number of bits in cycles counter
`define NRV_TWOLEVEL_SHIFTER        // Faster shifts
// tinyraytracer: 70 MHz, stick was 17:30 


/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

//`define NRV_RAM 6144 //6144 was default for ICESTICK 
`define NRV_RAM 14336 //(hx8k is double icestick BRAM capacity) 16384-2048 = 14336

/************************* Advanced devices configuration ***********************************************************/

`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file
`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (note: firmware libfemtorv32 depends on it)

/********************************************************************************************************************/

`define NRV_CONFIGURED
