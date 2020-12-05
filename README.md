# learn-fpga 
_Learning FPGA, yosys, nextpnr, and RISC-V_ 

Mission statement: create teaching material for FPGAs, processor design and RISC-V, using around $40 per students.

FemtoRV: a minimalistic RISC-V CPU
----------------------------------- 
FemtoRV is a minimalistic RISC-V design, with easy-to-read Verilog sources (less than 1000 lines), directly written
from the RISC-V specification. It includes a companion SOC, with drivers for an UART, a led matrix, a small OLED display,
SPI RAM and SDCard. Its most basic configuration fits on the Lattice IceStick (< 1280 LUTs). It can be used for teaching
processor design and RISC-V programming. More details are given [here](FemtoRV/README.md). 
    
Basic: more basic things I wrote during May 2020 - June 2020  
------------------------------------------------------------
- Blinker: the "hello world" program
- LedMatrix: play with a 8x8 let matrix, driven by a MAX7219 IC. 
- OLed: play with a SSD1351 OLed display, driven by a 4-wire SPI protocol.
- Serial: access the included USB-virtual UART pins
- LedTerminal: display scrolling messages on the LED matrix, obtained from the USB virtual UART
