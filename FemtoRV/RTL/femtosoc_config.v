// Configuration file for femtosoc/femtorv32

`ifdef ULX3S
`include "CONFIGS/ulx3s_config.v"
`endif

`ifdef ICE_STICK
`include "CONFIGS/icestick_config.v"
`endif

`ifdef ECP5_EVN
`include "CONFIGS/ecp5evn_config.v"
`endif

`ifndef NRV_CONFIGURED
`include "CONFIGS/generic_config.v"
`endif

/******************************************************************************/

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

`ifdef ICE_SUGAR
 `define ICE40
`endif

`ifdef ICE_SUGAR_NANO
 `define ICE40
 `define PASSTHROUGH_PLL
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

/******************************************************************************************************************/
