FEMTORV32 / FEMTOSOC: a minimalistic RISC-V CPU 
===============================================

_(Everything fit on the IceStick < 1280 LUTs)_
 
See instructions in the [Tutorials](TUTORIALS/README.md).

Features
--------

- Implements the RV32I or RV32IM instruction set (minus FENCE and SYSTEM).
- Synthesis using the freeware tools (Yosys and nextpnr).    
- Main goal: to be used for teaching, easy to read, fitting on the ICEstick, 
      fun demos (graphics), equip students for approx. $40.
- Disclaimer: I'm no FPGA expert, please feel free to comment, to
      give me some advice !
- Runs at 80MHz on the ICEStick and on the ULX3S.
- 6kb RAM (ICEStick) or 256kb (ULX3S)
- Firmware can be generated with gnu RISC-V toolsuite (script included), in C or in assembly.
- SOC memory-mapped device drivers and hardware for UART, built-in LEDs, OLed display, led matrix.
- femtolibC, femtoGL (everything fits in 6kb).
- includes @ultraembedded's fat_io_lib (access to FAT filesystem on SDCards).
- "femtOS" virtual output support: redirects printf() to UART, OLED screen (or led matrix, WIP).
- many RISC-V assembly and C demo programs, including graphics for the OLED display.

Performance (Dhrystones test)
-----------------------------

|Configuration                            | CPI   | Dhrystones/s/MHz | DMIPS/MHz |
|-----------------------------------------|-------|------------------|-----------|
|FemroRV32 with RV32I and simple shifter  | 3.663 |      580         |   0.330   |
|FemroRV32 with RV32I and 2-stage shifter | 3.587 |      592         |   0.336   |
|FemroRV32 with RV32I and barrel shifter  | 3.478 |      611         |   0.347   |
|FemroRV32 with RV32IM and barrel shifter | 3.692 |      1024        |   0.582   |

_last line (RV32IM) using ECP5 DSP blocs_
