FEMTORV32 / FEMTOSOC: a minimalistic RISC-V CPU 
===============================================

_(Everything fit on the IceStick < 1280 LUTs)_
 
Quick links: 
- [IceStick tutorial](TUTORIALS/IceStick.md)
- [ULX3S tutorial](TUTORIALS/ULX3S.md)
- [ECP5 eval board tutorial](TUTORIALS/ECP5_EVN.md)
- [FOMU tutorial](TUTORIALS/FOMU.md)
- [Adding a new board](TUTORIALS/newboard.md) 
- [More documentation...](TUTORIALS/README.md)

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
|FemroRV32 with RV32I and simple shifter  | 3.434 |      956         |   0.544   |
|FemroRV32 with RV32I and 2-stage shifter | 3.062 |     1072         |   0.610   |
|FemroRV32 with RV32I and barrel shifter  | 2.786 |     1178         |   0.670   |
|FemroRV32 with RV32IM and barrel shifter | 2.934 |     1241         |   0.706   |

_last line (RV32IM) using ECP5 DSP blocs_

LUT count (FemtoRV32 + FemtoSOC)
--------------------------------

Statistics measured with ICE40/IceStick target. 

| Parameter            | value1 | value2 | value3 |
|----------------------|--------|--------|--------|
| NRV_TWO_STAGE_SHIFTER| ON     | OFF    | OFF    |
| NRV_NEGATIVE_RESET   | OFF    | OFF    | OFF    |
| NRV_IO_LEDS          | ON     | ON     | ON     |
| NRV_IO_UART          | ON     | ON     | OFF    |
| NRV_IO_SSD1351       | OFF    | OFF    | OFF    |
| NRV_IO_MAX7219       | OFF    | OFF    | OFF    |
| NRV_IO_SPI_FLASH     | OFF    | OFF    | OFF    |
| NRV_FREQ             | 50     | 50     | 50     | 
| NRV_RAM              | 6144   | 6144   | 1024   |
| NRV_COUNTERS         | OFF    | OFF    | OFF    |
| NRV_COUNTERS_64      | OFF    | OFF    | OFF    |
| NRV_RV32M            | OFF    | OFF    | OFF    |
|                      |        |        |        |
| LUT count            | 1180   | 1140   | 980    |

First column is a standard configuration for IceStick (UART and LED configured, 6Kb RAM, two-level shifter). This
corresponds to the second line of the Dhrystones test. Second column measures the impact of the two-level shifter
(eats up 40 LUTs). Third column is a minimalistic configuration, with no peripheral (just LEDs) and minimal RAM,
to have an idea of how many LUTs the processor alone uses (less than 1000, achievement unlocked !).

FemtoRV32 makes a compromise between complexity (the sources fit in 1000 lines of Verilog and - I think - are easy to read),
LUT count (1000 is also the magic number here) and performance (around 1000 Dhrystones/s/MHz, most instructions take between
2 and 3 cycles). 

References to other RISC-V cores
--------------------------------

- The reference: Claire Wolf's [picorv32](https://github.com/cliffordwolf/picorv32) (borrowed many ideas from there).
- The smallest RISC-V: [SERV](https://github.com/olofk/serv), you can fit 5 instances (!) in 1000 LUTs.
- Faster cores, Linux capable cores: [biriscv](https://github.com/ultraembedded/biriscv/), [VexRiscv](https://github.com/SpinalHDL/VexRiscv)
- FemtoRV32's best friend: [ICE-V](https://github.com/sylefeb/Silice/tree/master/projects/ice-v),
     written in [Silice](https://github.com/sylefeb/Silice/) (a higher-level HDL)
     