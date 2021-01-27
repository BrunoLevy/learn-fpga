Run from SPI Flash
==================

This directory contains programs to be run from the SPI Flash of the
IceStick. It makes it possible to run programs that are much larger
(1MB) than what fits in the 6kB of BRAM available on the tiny Ice40hx1K (it has 8kB
but 2kB are used by FemtoRV32). This comes at the expense of a
sloooowwwww execution time (but it is probably possible to make it 10x faster using
a more advanced SPI controller).

Instructions
============

*Step 1* Configure femtosoc (`RTL/femtosoc_config.v`)
-----------------------------------------------------

```
//`include "CONFIGS/icestick_config.v"
`include "CONFIGS/icestick_spi_flash_config.v" // This one to run from spi-flash 
```

This does three things:
- include a `MappedSPIFlash` peripheral, mapped in the address space of FemtoRV32
- select the version of FemtoRV32 that waits for the flash memory when fetching instructions
- configure the reset address (where the processor jumps on reset) to the flash memory


You may also want to configure the peripherals you plan to use in `CONFIGS/icestick_spi_flash_config.v`.

*Step 2* Synthethize and flash
------------------------------
```
$ make ICESTICK
```

*Step 3* Generate a blinker that runs from SPI flash
----------------------------------------------------
```
$ cd FIRMWARE/SPI_FLASH
$ make blinker.prog
```
This compiles `blinker.c`, converts it to raw binary, and sends it to
the SPI flash using `iceprog -o 1M` (1 megabyte offset, it is where
FemtoRV32 expects to find code). Note: the first few kilobytes of the
SPI flash are used to store the design, so I wanted to make sure that
our programs do not interfere with it, and keep the address decoder 
super simple so that it fits on the IceStick. This wastes a lot
of SPI Flash, nearly 1MB, but the remaining 1MB will be sufficient to
store very large programs.

Other programs
--------------
If you have the SSD1351 small OLED screen, you can compile
`mandelbrot.c` (still using `make mandelbrot.flash`). You will see
how slow it is as compared to the version that runs from the BRAM !

There is also `mandelbrot_float.c` that uses software floating point
routines, and `tinyraytracer.c`. They are really super slow, but it
is interesting to see that large programs can run on the IceStick
directly from the SPI flash. 

WIP
---
Make it faster, using the XIP protocol, and configure number of dummy
cycles (tried without success).

Links
-----
- [Compiling software for the FemtoRV32](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/software.md)
