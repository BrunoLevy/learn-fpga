// Default femtosoc configuration file for IceStick

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS          // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Use with MINIRV32 to run code from SPI flash.

/************************* Frequency ********************************************************************************/

`define NRV_FREQ 65      // Frequency in MHz. 

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

`define NRV_RAM 262144     // RAM in bytes

/************************* Processor configuration ******************************************************************/

`define NRV_CSR         // Uncomment if using something below (counters,...)
`define NRV_COUNTERS    // Uncomment for instr and cycle counters (won't fit on the ICEStick)
`define NRV_COUNTERS_64 // ... and uncomment this one as well if you want 64-bit counters
`define NRV_RV32M       // Uncomment for hardware mul and div support (RV32M instructions). Not supported on IceStick !
`define NRV_LATCH_ALU   // Uncomment to latch all ALU ops (reduces critical path)

/************************* Advanced processor configuration *********************************************************/

`define NRV_RESET_ADDR 24'h000000

//`define NRV_RESET_ADDR 24'h810000  // Jump execution to SPI Flash (Mapped at 800000h, + leave 64k (10000h) for FPGA bitstream)

`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (only if you use your own firmware, libfemtorv32 depends on it)

/******************************************************************************************************************/
//`define NRV_RUN_FROM_SPI_FLASH // Do not 'readmemh()' firmware from '.hex' file

`define NRV_CONFIGURED
