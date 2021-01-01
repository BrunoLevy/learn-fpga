// Configuration file for femtosoc/femtorv32

/************************* Devices **********************************************************************************/

`define NRV_IO_LEDS      // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_IO_UART      // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1351    // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX7219      // Mapped IO, 8x8 led matrix
//`define NRV_IO_SPI_FLASH  // Mapped IO, SPI flash  
`define NRV_IO_SPI_SDCARD // Mapped IO, SPI SDCARD
`define NRV_IO_BUTTONS    // Mapped IO, buttons
//`define NRV_MAPPED_SPI_FLASH // SPI flash mapped in address space. Use with MINIRV32 to run code from SPI flash.

/************************* Frequency ********************************************************************************/

`define NRV_FREQ 100      // Frequency in MHz. Recomm: 50 MHz (FOMU: 16MHz) Overclocking: 80-100 MHz (HX1K, ECP5)

/************************* RAM (in bytes, needs to be a multiple of 4)***********************************************/

//`define NRV_RAM 393216 // bigger config for ULX3S
`define NRV_RAM 262144 // default for ULX3S
//`define NRV_RAM 6144     // default for ICESTICK (cannot do more !)
//`define NRV_RAM 1024   // small ICESTICK config (to further save LUTs if need be)

/************************* Processor configuration ******************************************************************/

//`define NRV_MINIRV32 // Mini config, can execute code stored in SPI flash from 1Mb offset (mapped to address 0x800000)

`ifndef NRV_MINIRV32 // The options below are not supported by minifemtorv32
`define NRV_CSR         // Uncomment if using something below (counters,...)
`define NRV_COUNTERS    // Uncomment for instr and cycle counters (won't fit on the ICEStick)
`define NRV_COUNTERS_64 // ... and uncomment this one as well if you want 64-bit counters
`define NRV_RV32M       // Uncomment for hardware mul and div support (RV32M instructions). Not supported on IceStick !
`define NRV_TWOSTAGE_SHIFTER // if not RV32M, comment-out if running out of LUTs (at the expense of slower shifts)
`define NRV_LATCH_ALU // Uncomment to latch all ALU ops (reduces critical path)
`endif

/************************* Advanced processor configuration *********************************************************/

`define NRV_RESET_ADDR 0                // The address the processor jumps to on reset 
//`define NRV_RESET_ADDR 32'h00800000  // If using NRV_MINIRV32 and mapped SPI Flash, you may want to jump to
                                        // a bootloader or firmware stored there.

`define NRV_IO_HARDWARE_CONFIG // Comment-out to disable hardware config registers mapped in IO-Space
                               // (only if you use your own firmware, libfemtorv32 depends on it)
/* 
 * Uncomment if the RESET button is wired and active low:
 * (wire a push button and a pullup resistor to 
 * pin 47 or change in nanorv.pcf). 
 */
`ifdef ICE_STICK
//`define NRV_NEGATIVE_RESET 
`endif

`ifdef FOMU
`define NRV_NEGATIVE_RESET
`endif

/************************ Normally you do not need to change anything beyond that point ****************************/

`ifdef NRV_IO_SPI_FLASH
`define NRV_SPI_FLASH
`endif

`ifdef NRV_MAPPED_SPI_FLASH
`define NRV_SPI_FLASH
`endif

/*
 * On the ECP5 evaluation board, there is already a wired button, active low,
 * wired to the "P4" ball of the ECP5 (see ecp5_evn.lpf)
 */ 
`ifdef ECP5_EVN
`define NRV_NEGATIVE_RESET
`endif

// Toggle FPGA defines (ICE40, ECP5) in function of board defines (ICE_STICK, ECP5_EVN)
// Board defines are set in Makefile.

`ifdef ICE_STICK
 `define ICE40
`endif

`ifdef ICE_FEATHER
 `define ICE40
`endif

`ifdef FOMU
 `define ICE40
`endif

`ifdef ECP5_EVN
 `define ECP5 
`endif

`ifdef ULX3S
 `define ECP5 
`endif

`default_nettype none // Makes it easier to detect typos !

/******************************************************************************************************************/
