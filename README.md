# learn-fpga 
_Learning FPGA, yosys, nextpnr, and RISC-V_ 

Mission statement: create teaching material for FPGAs, processor design and RISC-V, using around $40 per students.

![](FemtoRV/TUTORIALS/Images/IceStick_hello.gif)

FemtoRV: a minimalistic RISC-V CPU
----------------------------------- 
[FemtoRV](FemtoRV/README.md) is a minimalistic RISC-V design, with
easy-to-read Verilog sources directly written from the RISC-V specification. 
The most elementary version (quark), an RV32I core, weights 400 lines of VERILOG
(documented version), and 100 lines if you remove the comments. There
are also more elaborate versions, the biggest one (petitbateau) is an RV32IMFC
core. The repository also includes a companion SoC, with
drivers for an UART, a led matrix, a small OLED display, SPI RAM and
SDCard. Its most basic configuration fits on the Lattice IceStick (<
1280 LUTs). It can be used for teaching processor design and RISC-V
programming.


Playing with LiteX: plug-and-play system to assemble SOCs
---------------------------------------------------------
The repository includes [LiteX examples](LiteX/README.md).
The [LiteX](https://github.com/enjoy-digital/litex) framework 
is a well designed and an easy-to-use framework to create SoCs. 
It lets you create a SoC by assembling components (processor, 
SDRAM controller, SDCard controller, USB, ...) in Python.
FemtoRV is directly supported by LiteX (that directly downloads
it from this repository when selected as the SoC's processor). 

From Blinky to RISC-V
---------------------
In [Episode I](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/README.md),
you will learn to build your own RISC-V processor, step by step,
starting from the simplest design (that blinks a LED), to a fully
functional RISC-V core that can compute and display graphics.

In [Episode II](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/PIPELINE.md),
you will learn how to design a pipelined processor.

Links - Other FPGA resources
----------------------------
- [TinyPrograms](https://github.com/BrunoLevy/TinyPrograms) Tiny yet interesting C programs to play with your softcore
- [LiteX](https://github.com/enjoy-digital/litex) Framework in Amaranth (Python-based HDL) to build SOCs
- [Silice](https://github.com/sylefeb/Silice) A new HDL by my friend Sylvain Lefebvre
- [FuseSOC](https://github.com/olofk/fusesoc) and [Edalize](https://github.com/olofk/edalize), package manager and abstraction of FPGA tools
- [PipelineC](https://github.com/JulianKemmerer/PipelineC) Transform a C program into a pipelined specialized core !
- [ultraembedded](https://github.com/ultraembedded/) Amazing resources, [FatIOLib](https://github.com/ultraembedded/fat_io_lib),[ExactStep](https://github.com/ultraembedded/exactstep)...
- [picoRV](https://github.com/YosysHQ/picorv32) by Claire Wolf, my principal source of inspiration
- [VexRiscV](https://github.com/SpinalHDL/VexRiscv) and [NaxRiscV](https://github.com/SpinalHDL/NaxRiscv), performant and configurable pipelined and OoO cores, by Charles Papon, in SpinalHDL
- [SERV](https://github.com/olofk/serv) the tiniest RiscV core, with a bit-serial ALU
- [DarkRiscV](https://github.com/darklife/darkriscv) a simple pipelined core (written in one night according to the legend)
- [kianRiscV](https://github.com/splinedrive/kianRiscV) a simple yet complete Linux-capable core + soc
- [Will Green's project F](https://github.com/projf/projf-explore) tutorials with nice graphics effects
- [fpga4fun](https://www.fpga4fun.com/) learned there how to create VGA graphics
- [CoreScore](https://corescore.store/) how many cores can you fit on a FPGA ?

Basic: more basic things I wrote during May 2020 - June 2020  
------------------------------------------------------------
Files are [here](https://github.com/BrunoLevy/learn-fpga/tree/master/Basic).
This includes:
- Blinker: the "hello world" program
- LedMatrix: play with a 8x8 let matrix, driven by a MAX7219 IC. 
- OLed: play with a SSD1351 OLed display, driven by a 4-wire SPI protocol.
- Serial: access the included USB-virtual UART pins
- LedTerminal: display scrolling messages on the LED matrix, obtained from the USB virtual UART
- FOMU: simple examples for the "FPGA in a USB dongle", including the FrankenVGA experiment !
- ULX3S HDMI: simple self-contained heavily commented HDMI example.