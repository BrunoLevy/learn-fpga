# learn-fpga
Learning FPGA, yosys, nextpnr, and RISC-V 

This repository contains my little experiments with an IceStick, yosys and nextpnr, learning VERILOG design.

* FemtoRV: a minimalistic RISC-V CPU, and companion SOC, that fit on the IceStick (< 1280 LUTs) 
    - Implements the RV32I instruction set (minus FENCE and SYSTEM). 
    - Runs at 60MHz. 4Kb RAM, optional memory-mapped IOs (UART, LEDs, OLed screen).
    - Synthesis using the freeware tools (Yosys and nextpnr).
    - Firmware can be generated with gnu RISC-V toolsuite (script included), in C or in assembly.
    - SOC memory-mapped device drivers and hardware for UART, built-in LEDs, OLed display, led matrix.
    - femtOS, femtoGL (everything fits in 4kb / 6kb).
    - many RISC-V assembly and C demo programs, including graphics for the OLED display.
    
* More basic things I wrote during May 2020 - June 2020  
    - Blinker: the "hello world" program
    - LedMatrix: play with a 8x8 let matrix, driven by a MAX7219 IC. 
    - OLed: play with a SSD1351 OLed display, driven by a 4-wire SPI protocol.
    - Serial: access the included USB-virtual UART pins
    - LedTerminal: display scrolling messages on the LED matrix, obtained from the USB virtual UART
