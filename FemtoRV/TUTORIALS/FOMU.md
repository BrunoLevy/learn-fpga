FOMU Tutorial (WIP)
===================

_Note: the following instructions are for Linux (I'm using Ubuntu).
Windows users can run the tutorial using WSL. It requires some
adaptation, as explained [here](WSL.md)._

Step 0: install FemtoRV
=======================
```
$ git clone https://github.com/BrunoLevy/learn-fpga.git
```

Step 1: install FPGA development tools
======================================

You can find precompiled toolchains for FOMU
[here](https://workshop.fomu.im/en/latest/requirements/software.html).
Alternatively, if you want a cutting-edge yosys/nextpnr, you can install 
them from the sources as follows:

Yosys
-----

Follow setup instructions from [yosys website](https://github.com/YosysHQ/yosys)

*TL;DR*

Install prerequisites:
```
$ sudo apt-get install build-essential clang bison flex \
  libreadline-dev gawk tcl-dev libffi-dev git \
  graphviz xdot pkg-config python3 libboost-system-dev \
  libboost-python-dev libboost-filesystem-dev zlib1g-dev
```
Get the sources:
```
$ git clone https://github.com/YosysHQ/yosys.git
```
Compile and install it:
```
$ cd yosys
$ make
$ sudo make install
```

IceStorm
--------

Follow setup instructions from [icestorm website](https://github.com/YosysHQ/icestorm)

*TL;DR*

Install prerequisites:
```
$ sudo apt-get install build-essential clang bison flex libreadline-dev \
  gawk tcl-dev libffi-dev git mercurial graphviz   \
  xdot pkg-config python python3 libftdi-dev \
  qt5-default python3-dev libboost-all-dev cmake libeigen3-dev
```
Get the sources:
```
$ git clone https://github.com/YosysHQ/icestorm.git
```
Compile and install it:
```
$ cd icestorm
$ make -j 4
$ sudo make install
```

NextPNR
-------

Follow setup instructions from [nextpnr website](https://github.com/YosysHQ/nextpnr)

*TL;DR*


Get the sources:
```
$ git clone https://github.com/YosysHQ/nextpnr.git
```
Compile and install it:
```
$ cd nextpnr
$ cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=/usr/local .
$ make -j 4
$ sudo make install
```

Step 2: Configure DFU and USB rules
===================================

We need to let normal users program the IceStick through USB. This
can be done by creating in `/etc/udev/rules.d` a file `99-fomu.rules`
with the following content:
```
SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="5bf0", MODE="0664", GROUP="plugdev"
```

Install dfu-util:
```
$ sudo apt-get install dfu-util  
```

Plug the FOMU and test it:
```
$ dfu-util -l
```
It should display something like:
```
dfu-util 0.9

Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
Copyright 2010-2016 Tormod Volden and Stefan Schmidt
This program is Free Software and has ABSOLUTELY NO WARRANTY
Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

Found DFU: [1209:5bf0] ver=0101, devnum=20, cfg=1, intf=0, path="1-1", alt=0, name="Fomu PVT running DFU Bootloader v1.9.1", serial="UNKNOWN"
```

Step 3: Test a simple FOMU design (optional)
============================================

```
$ cd learn_fpga/Basic/FomuBlink
$ ./make_it.sh
```

The FOMU should nicely glow in blue while downloading the
bitstream, then blinking in different colors. With the FOMU,
you only have one LED to output something, but it is in
*colors* !

Step 4: Configure femtosoc and femtorv32
========================================
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

`define NRV_FREQ 24         // Frequency in MHz. 
                                                  
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

Step 5: Configure and compile firmware
======================================
Now, edit `FemtoRV/FIRMWARE/makefile.inc`. You have two things to do,
first indicate where the firmware sources are installed in the `FIRMWARE_DIR`
variable. Second, chose the architecture, ABI and optimization flags
as follows:
```
ARCH=rv32i
ABI=ilp32
OPTIMIZE=-Os
```
Then, compile a RISC-V blinky as follows:
```
$ cd FIRMWARE
$ ./make_firmware.sh ASM_EXAMPLES/blinker_loop.S
$ cd ..
```

Step 6: Synthethize and send to device
======================================

```
$ make FOMU
```

Quite a convoluted way of obtaining more or less the same blinky as in step 3, but this blinky is much cooler:
it is written in assembly, stored in BRAMs, and executed by a RISC-V core !

Coming next ...
===============

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
