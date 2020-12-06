IceStick Tutorial
=================

Before starting, you will need to install the OpenSource FPGA
development tools, Yosys (Verilog synthesis), IceStorm (tools for
Lattice Ice40 FPGA), NextPNR (Place and Route). Although there 
exists some precompiled packages, I highly recommend to get fresh
source versions from the repository, because the tools quickly 
evolve.


Step 1: install FPGA development tools
======================================

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

Step 2: Configure USB rules
===========================
We need to let normal users program the IceStick through USB. This
can be done by creating in `/etc/udev/rules.d` a file `53-lattive-ftdi.rules` 
with the following content:
```
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0660", GROUP="plugdev", TAG+="uaccess"
```

Step 3: Configure femtosoc and femtorv32
========================================
Time to edit `FemtoRV/femtosoc.v`. This file lets you define what time
of RISC-V processor you will create, and which device drivers in the
associated system-on-chip. For now we activate the LEDs (for visual
debugging) and the UART (to talk with the system through a
terminal-over-USB connection). We use 6144 bytes of RAM. It is not 
very much, but we cannot do more on the IceStick. You will see that
with 6k of RAM, you can still program nice and interesting RISC-V
demos. The file contains some `CONFIGWORD` commands that need to
be kept: the firmware generation tool uses them to store the hardware
configuration in some predefine memory areas. 


We configure `FemtoRV/femtosoc.v` as follows (we keep unused options as commented-out lines):
```
/*
 * Optional mapped IO devices
 */
`define NRV_IO_LEDS         // CONFIGWORD 0x0024[0]  // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
`define NRV_IO_UART         // CONFIGWORD 0x0024[1]  // Mapped IO, virtual UART (USB)
//`define NRV_IO_SSD1351      // CONFIGWORD 0x0024[2]  // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX2719      // CONFIGWORD 0x0024[3]  // Mapped IO, 8x8 led matrix
//`define NRV_IO_SPI_FLASH    // CONFIGWORD 0x0024[4]  // Mapped IO, SPI flash  
//`define NRV_IO_SPI_SDCARD   // CONFIGWORD 0x0024[5]  // Mapped IO, SPI SDCARD
//`define NRV_IO_BUTTONS      // CONFIGWORD 0x0024[6]  // Mapped IO, buttons

`define NRV_FREQ 80        // CONFIGWORD 0x001C // Frequency in MHz. Can push it to 80 MHz on the ICEStick.
                                                  
// Quantity of RAM in bytes. Needs to be a multiple of 4. 
// Can be decreased if running out of LUTs (address decoding consumes some LUTs).
// 6K max on the ICEstick
// Do not forget the CONFIGWORD 0x0020 comment (FIRMWARE_WORDS depends on it)
//`define NRV_RAM 393216       // CONFIGWORD 0x0020 // bigger config for ULX3S
//`define NRV_RAM 262144       // CONFIGWORD 0x0020 // default for ULX3S
//`define NRV_RAM 131072       // CONFIGWORD 0x0020 // You need at least this to run DHRYSTONE
//`define NRV_RAM 65536        // CONFIGWORD 0x0020
`define NRV_RAM 6144         // CONFIGWORD 0x0020 // default for IceStick (maximum)
//`define NRV_RAM 4096         // CONFIGWORD 0x0020 // smaller for IceStick (to save LUTs)

//`define NRV_COUNTERS    // CONFIGWORD 0x0018[0] // Uncomment for instr and cycle counters (won't fit on the ICEStick)
//`define NRV_COUNTERS_64 // CONFIGWORD 0x0018[1] // ... and uncomment this one as well if you want 64-bit counters
//`define NRV_RV32M       // CONFIGWORD 0x0018[2] // Uncomment for hardware mul and div support (RV32M instructions)

/*
 * For the small ALU (that is, when not using RV32M),
 * comment-out if running out of LUTs (makes shifter faster, 
 * but uses 60-100 LUTs) (inspired by PICORV32). 
 */ 
`define NRV_TWOSTAGE_SHIFTER 
```

Step 4: Configure firmware
==========================
Now, edit `FemtoRV/FIRMWARE/makefile.inc`. You have two things to do,
first indicate where the firmware sources are installed in the `FIRMWARE_DIR`
variable. Second, chose the architecture, ABI and optimization flags
as follows:
```
ARCH=rv32i
ABI=ilp32
OPTIMIZE=-Os
```
Remember, on the IceStick, we do not have enough LUTs to support
hardware multiplications (M instruction set), and we only have 6k of RAM
(then we optimize for size, memory is precious !).

Step 5: Examples
================
You can now compile the firmware, synthesize the design and send it to the device:
```
$make ICESTICK
```
The first time you run it, it will download RISC-V development tools (takes a while).
The default firmware outputs a welcome message to the terminal-over-USB port. First,
install a terminal emulator:
```
$sudo apt-get install python3-serial
```
(or `sudo apt-get install screen`, both work).
To see the output, you need to connect to it (using the terminal emulator):
```
$make terminal
```
(if you installed `screen` instead of `python3-serial`, edit `Makefile` before accordingly).

To exit, press `<ctrl> ]` (python-3-serial/miniterm), or `<ctrl> a` then '\' (screen).

Examples with the serial terminal (UART)
----------------------------------------
The directories `FIRMWARE/EXAMPLES` and `FIRMWARE/ASM_EXAMPLES` contain programs in C and assembly
that you can run on the device. On the IceStick, only those that use 6K or less will work (list below).

To compile a program:
```
$cd FIRMWARE
$./make_firmware.sh EXAMPLES/NNNN.c
```
or:
```
$cd FIRMWARE
$./make_firmware.sh ASM_EXAMPLES/NNNN.c
```

Then send it to the device and connect to the device using the terminal emulator:
```
$cd ..
$make ICESTICK terminal
```

There are several C and assembly programs you can play with (list below). To learn more about RISC-V assembly, you can
read the manual [here](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md).

| Program                                | Description                                                    |
|----------------------------------------|----------------------------------------------------------------|
| `ASM_EXAMPLES/blinker_shift.S`         | the blinker program, using shifts                              |
| `ASM_EXAMPLES/blinker_wait.S`          | the blinker program, using a delay loop                        |
| `ASM_EXAMPLES/test_serial.S`           | reads characters from the serial over USB, and sends them back |
| `ASM_EXAMPLES/mandelbrot_terminal.c`   | computes the Mandelbrot set and displays it in ASCII art       |
| `EXAMPLES/hello.c`                     | displays a welcome message                                     |
| `EXAMPLES/sieve.c`                     | computes prime numbers                                         |

Examples with the LED matrix
----------------------------

Examples with the OLED screen
------------------------------

