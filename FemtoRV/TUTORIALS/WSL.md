Windows/WSL Tutorial (WIP)
==========================

My tutorials are mainly adapted to Linux users (I'm using Ubuntu). It 
is possible to make everything work under Windows using WSL, however,
USB under Windows is tricky !

Some precompiled binaries and instructions (including about how to make USB work)
are available [here](https://github.com/sylefeb/fpga-binutils/).

@gojimmypi reported a success and explains how to do that
[here](https://gojimmypi.blogspot.com/2020/12/ice40-fpga-programming-with-wsl-and.html).
Synthetizing the core, compiling RISC-V code and flashing the device
work. 

Under Windows, talking to the device through a terminal emulator doesn't always work.
The solution may be [here](https://github.com/rpasek/usbip-wsl2-instructions).

