// Configuration file for femtosoc/femtorv32

`ifdef BENCH_VERILATOR
`define BENCH
`endif

`ifdef ULX3S
`include "CONFIGS/ulx3s_config.v"
`endif

`ifdef ICE_STICK
`include "CONFIGS/icestick_config.v"
`endif

`ifdef ICE_BREAKER
`include "CONFIGS/icebreaker_config.v"
`endif

`ifdef ECP5_EVN
`include "CONFIGS/ecp5evn_config.v"
`endif

`ifdef ARTY
`include "CONFIGS/arty_config.v"
`endif

`ifdef ICE_SUGAR_NANO
`include "CONFIGS/icesugarnano_config.v"
`endif

`ifdef CMODA7
`include "CONFIGS/cmod_a7_config.v"
`endif

`ifdef TANGNANO9K
`include "CONFIGS/tangnano9k_config.v"
`endif

`ifdef TANGNANO20K
`include "CONFIGS/tangnano20k_config.v"
`endif

`ifdef BENCH_VERILATOR
`include "CONFIGS/bench_config.v"
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

`ifdef ICE_BREAKER
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
/* Processor */

`define NRV_IS_IO_ADDR(addr) |addr[23:22] // Asserted if address is in IO space (then it needs additional wait states)

`include "PROCESSOR/utils.v"

`ifdef NRV_FEMTORV32_QUARK
 `include "PROCESSOR/femtorv32_quark.v" // Minimalistic version of the processor for IceStick (RV32I)
`endif

`ifdef NRV_FEMTORV32_QUARK_BICYCLE
 `include "PROCESSOR/femtorv32_quark_bicycle.v" // Quark with Matthias's 2 CPI mode and barrel shifter (RV32I)
`endif

`ifdef NRV_FEMTORV32_TACHYON
 `include "PROCESSOR/femtorv32_tachyon.v" // Version for the IceStick with higher maxfreq (RV32I)
`endif

`ifdef NRV_FEMTORV32_ELECTRON
 `include "PROCESSOR/femtorv32_electron.v" // RV32IM with barrel shifter
`endif

`ifdef NRV_FEMTORV32_INTERMISSUM
 `include "PROCESSOR/femtorv32_intermissum.v" // RV32IM with barrel shifter and interrupts
`endif

`ifdef NRV_FEMTORV32_GRACILIS
 `include "PROCESSOR/femtorv32_gracilis.v" // RV32IMC with barrel shifter and interrupts
`endif

`ifdef NRV_FEMTORV32_PETITBATEAU
 `include "PROCESSOR/femtorv32_petitbateau.v" // under development, RV32IMFC
`endif

`ifdef NRV_FEMTORV32_TESTDRIVE
 `include "PROCESSOR/femtorv32_testdrive.v" // CPU under test
`endif

/******************************************************************************************************************/
