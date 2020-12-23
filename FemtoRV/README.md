FEMTORV32 / FEMTOSOC: a minimalistic RISC-V CPU 
===============================================

_(Everything fit on the IceStick < 1280 LUTs)_
 
Quick links: 
- [IceStick tutorial](TUTORIALS/IceStick.md)
- [ULX3S tutorial](TUTORIALS/ULX3S.md)
- [ECP5 eval board tutorial](FemtoRV/TUTORIALS/ECP5_EVN.md)
- [FemtoRV32 design notes](TUTORIALS/FemtoRV32.md)

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

On IceStick: 1180 LUTs with the following `RTL/femtosoc_config.v` configuration:

| Parameter            | value |
|----------------------|-------|
| NRV_TWO_STAGE_SHIFTER| ON    |
| NRV_NEGATIVE_RESET   | OFF   |
| NRV_IO_LEDS          | ON    |
| NRV_IO_UART          | ON    |
| NRV_IO_SSD1351       | OFF   |
| NRV_IO_MAX7219       | OFF   |
| NRV_IO_SPI_FLASH     | OFF   |
| NRV_FREQ             | 80    |
| NRV_RAM              | 6144  |
| NRV_COUNTERS         | OFF   |
| NRV_COUNTERS_64      | OFF   |
| NRV_RV32M            | OFF   |
