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

*Step 1* Configure in `RTL/CONFIGS/icestick_config.v` 
-----------------------------------------------------

```
`define NRV_IO_LEDS
   ... \\ activate the devices that you need
`define NRV_MAPPED_SPI_FLASH \\ you will need this one
`define NRV_RAM 6144
`define NRV_MINIRV32
`define NRV_IO_HARDWARE_CONFIG
`define NRV_RUN_FROM_SPI_FLASH
```

*Step 2* Replace the firmware with one that jumps to the SPI flash
------------------------------------------------------------------
(normally there will be a `NRV_RESET_ADDR` to do that, but it does
not seem to work for no)
```
$ cd FIRMWARE
$ ./make_firmware.sh ASM_EXAMPLES/jump_to_spi_flash.S
$ cd ..
```

*Step 3* Synthethize and flash
------------------------------
```
$ make ICESTICK
```

*Step 4* Generate a blinker that runs from SPI flash
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

Remaining issues
----------------
The segments of initialized read-write data cannot be properly mapped
to memory: intialization data should be put in ROM (SPI flash), and
the segment should be put in RAM (BRAM), and initialization data copied
there at program startup. For now, these segments are mapped to ROM,
because if mapped to RAM, the execution image becomes too large (spans
the entire address space) and can no longer be stored on the SPI flash. 
It would be possible to have a conversion program, that reads the elf
executable, puts initialization data at the right locations in ROM,
and generates a code that copies them to the segments in RAM.

It is probably possible to make it 10x faster, by using a faster clock for
the SPI, by using DDR blocks to generate the SPI clock, by using faster SPI
protocols (dual IO)...