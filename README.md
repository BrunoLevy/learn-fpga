# learn-fpga
Learning FPGA, yosys, nextpnr, and RISC-V 

This repository contains my little experiments with an IceStick, yosys and nextpnr, learning VERILOG design.

* Blinker: the "hello world" program
* LedMatrix: play with a 8x8 let matrix, driven by a MAX7219 IC. 
* OLed: play with a SSD1351 OLed display, driven by a 4-wire SPI protocol.
* Serial: access the included USB-virtual UART pins
* LedTerminal: display scrolling messages on the LED matrix, obtained from the USB virtual UART
* NanoRV: a minimalistic RISC-V CPU. Implements the RV32I instruction set (minus FENCE and SYSTEM). 
    - Runs at 60MHz. 2Kb ROM, 4Kb RAM, optional memory-mapped IOs (UART, LEDs, OLed screen).
    - Firmware can be generated with gnu RISC-V toolsuite (script included), and soon gcc.
