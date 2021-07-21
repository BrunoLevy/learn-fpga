FOMU Tutorial (WIP)
===================

Install open-source FPGA development toolchain
==============================================
Before starting, you will need to install the open-source FPGA
development toolchain (Yosys, NextPNR etc...), instructions to
do so are given [here](toolchain.md).


Test a simple FOMU design (optional)
====================================

```
$ cd learn-fpga/Basic/FOMU/FOMU_blink
$ ./makeit.sh
```

The FOMU should nicely glow in blue while downloading the
bitstream, then blinking in different colors. With the FOMU,
you only have one LED to output something, but it is in
*colors* !

Configure femtosoc and femtorv32
================================
Time to edit `learn-fpga/FemtoRV/RTL/femtosoc_config.v`. This file lets you define what type
of RISC-V processor you will create, and which device drivers in the
associated system-on-chip. For now we activate the LEDs (for visual
debugging). We use 6144 bytes of RAM for now.

We configure `FemtoRV/RTL/femtosoc_config.v` as follows (we keep unused options as commented-out lines):
```
/*
 * Optional mapped IO devices
 */
`define NRV_IO_LEDS         // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_IO_UART         // Mapped IO, virtual UART (USB)
//`define NRV_IO_SSD1351      // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX7219      // Mapped IO, 8x8 led matrix
//`define NRV_IO_SPI_FLASH    // Mapped IO, SPI flash  
//`define NRV_IO_SPI_SDCARD   // Mapped IO, SPI SDCARD
//`define NRV_IO_BUTTONS      // Mapped IO, buttons

`define NRV_FREQ 16         // Frequency in MHz. 
                                                  
// Quantity of RAM in bytes. Needs to be a multiple of 4. 
// Can be decreased if running out of LUTs (address decoding consumes some LUTs).
// 6K max on the ICEstick
//`define NRV_RAM 393216       // bigger config for ULX3S
//`define NRV_RAM 262144       // default for ULX3S
`define NRV_RAM 6144         // default for IceStick (maximum)
//`define NRV_RAM 4096         // smaller for IceStick (to save LUTs)

//`define NRV_CSR         // Uncomment if using something below (counters,...)
//`define NRV_COUNTERS    // Uncomment for instr and cycle counters (won't fit on the ICEStick)
//`define NRV_COUNTERS_64 // ... and uncomment this one as well if you want 64-bit counters
//`define NRV_RV32M       // Uncomment for hardware mul and div support (RV32M instructions)

/*
 * For the small ALU (that is, when not using RV32M),
 * comment-out if running out of LUTs (makes shifter faster, 
 * but uses 60-100 LUTs) (inspired by PICORV32). 
 */ 
`define NRV_TWOSTAGE_SHIFTER 
```

Compile firmware
================
Compile a RISC-V blinky as follows:
```
$ cd FIRMWARE
$ ./make_firmware.sh ASM_EXAMPLES/blinker_loop.S
$ cd ..
```

Synthethize and send to device
==============================

```
$ make FOMU
```

Quite a convoluted way of obtaining more or less the same blinky as in step 3, but this blinky is much cooler:
it is written in assembly, stored in BRAMs, and executed by a RISC-V core !

Coming next ...
===============

There are still things that I do not understand: at 24 MHz, it blinks
slowlier than at 16 MHz, and at 20 MHz, it gets stuck. _To be
understood_.

Now it would seem natural to activate the UART. However, the FOMU does not have the FTDI chip that implements
serial over USB, here you are on your own, and need to implement the gateware for the USB stack. It can be
done, [here](https://github.com/rob-ng15/Verilog-Playground/tree/master/j1eforth-verilog) there is an implementation of the J1 processor
that has the UART-over-USB. It is a big things, with no less than
[17 verilog files !](https://github.com/rob-ng15/Verilog-Playground/tree/master/j1eforth-verilog/tinyfpga_bx_usbserial/usb).
Well, if somebody wants to interface it, you can put it in `RTL/DEVICES/USB` and send me a PR once it works.

There is much more that we can do with the FOMU, it has ample room for more functionalities, it has hardware
mutlipliers (DSP blocs), and RV32IM works without needing any modification (activate it in `RTL/femtosoc_config.v`).
It has ample quantities of RAM that we can use (single-ported RAM), using a special `SB_SPRAM256KA` bloc, see
[here](https://github.com/rob-ng15/Verilog-Playground/blob/master/j1eforth-verilog/j1eforth.v).

I'd like also to wire a 8x8 led matrix. It requires soldering 3 wires to the pads, and two additional wires
(gnd and vcc) on the other side. 

__To be continued__

Links
-----
[FOMU tutorials](https://workshop.fomu.im/en/latest/)
