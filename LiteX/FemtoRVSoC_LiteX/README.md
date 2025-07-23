# FemtoRVSoC – Minimal RISC-V SoC for the VSD Mini FPGA

This project implements a minimal RISC-V SoC on the VSD Mini FPGA board using the LiteX framework. It uses the FemtoRV32-quark core and focuses on ultra-low resource usage, targeting the Lattice iCE40UP5K FPGA.

The system was designed to support basic peripherals like UART and RGB LED, with all firmware running from an integrated 2 KB ROM. The project is intended for educational use and aims to demonstrate SoC construction with open-source tools.
## What is LiteX?

[LiteX](https://github.com/enjoy-digital/litex) is a flexible and open-source SoC (System-on-Chip) builder framework built on top of [Migen](https://github.com/m-labs/migen), a Python-based hardware description language (HDL). LiteX is designed to simplify the creation of complex digital systems by abstracting away much of the low-level wiring, integration, and boilerplate code required in FPGA designs.

With LiteX, developers can:

- Quickly assemble RISC-V (and other) CPU cores, memories, and peripherals.
- Generate the SoC’s interconnects (Wishbone, AXI, or Avalon-style) automatically.
- Create memory maps and corresponding C headers (`csr.csv`, `mem.h`, etc.).
- Automatically produce Verilog code from Python descriptions for synthesis.
- Generate firmware build systems (`Makefile`, linker scripts, startup code).
- Support multiple simulation backends (Verilator, ModelSim, etc.).
- Integrate with third-party IP cores and extend via custom modules.

LiteX is widely used in FPGA-based research, education, and even industrial applications, particularly for RISC-V-based soft cores. Its modular structure, powerful scripting, and integration with platforms like [LiteX-Boards](https://github.com/litex-hub/litex-boards) and [LiteX-BIOS](https://github.com/enjoy-digital/litex/wiki/LiteX-BIOS) make it an excellent tool for both prototyping and deployment.

It supports popular open-source RISC-V CPUs such as:

- [VexRiscv](https://github.com/SpinalHDL/VexRiscv)
- [SERV](https://github.com/olofk/serv)
- [FemtoRV32](https://github.com/BrunoLevy/femtorv32)
- [Picorv32](https://github.com/cliffordwolf/picorv32)

LiteX is maintained by [Enjoy Digital](https://enjoy-digital.fr) and supported by a vibrant community of open-source FPGA developers.


## Project Goals

* Build a minimal RISC-V system with the FemtoRV32 CPU
* Blink the onboard RGB LED through memory-mapped registers
* Print messages over UART (currently under debug)
* Avoid use of BRAM or RAM to stay under FPGA constraints
* Use open-source tools (Yosys, nextpnr, LiteX) only


## Hardware Target

* Board: VSD Mini FPGA
* FPGA: Lattice iCE40UP5K
* Clock: 12 MHz internal oscillator (SB_HFOSC)
* Peripherals: RGB LED, UART TX/RX
* CPU: FemtoRV32-quark (RV32I)


## File Structure

* soc.py – Top-level LiteX SoC build script
* platforms/vsd_mini_fpga.py – Platform definition and pin mapping
* firmware/ – Contains main.c and compiled firmware.hex
* build/ – Auto-generated files after build (bitstream, csr.csv, etc.)


## Memory Map (from csr.csv)

* LED register: 0x82000000
* UART base: 0x82001000
* Control register: 0x82000800



## UART Debugging (In Progress)

The LiteX UART peripheral is correctly mapped at 0x82001000 and included in the SoC build. However, UART output is not yet visible on serial terminals.

Possible issues include:

* Baud rate mismatch (target was 115200 bps)
* Missing txready polling in firmware
* Synthesis optimizations removing unused logic
* Peripheral enable/config not handled in firmware


This will be further debugged using test firmware and logic analyzers.

## Build Instructions

1. Compile firmware:


* Go to firmware directory
* Run make to generate firmware.hex


1. Build SoC:

~~~
python3 soc.py --cpu-type femtorv --cpu-variant quark --build
~~~
1. Flash Bitstream:

~~~
sudo iceprog build/gateware/vsd_mini_fpga.bin or --load option in LiteX script
~~~

## Toolchain

* riscv32-unknown-elf-gcc (built from source with newlib)
* Yosys (for synthesis)
* nextpnr-ice40 (for place and route)
* icepack / iceprog (for bitstream and flashing)


## Learnings and Status

* Successfully built a fully functional LiteX SoC on a minimal board
* LED blinking confirmed, SoC properly booting firmware from ROM
* UART still under investigation, next step is confirming data path and firmware logic
* Gained familiarity with LiteX internals, CSR mapping, FemtoRV architecture, and Python-based SoC design


## Credits

- [FemtoRV32](https://github.com/BrunoLevy/femtorv32) by Bruno Levy  
- [LiteX](https://github.com/enjoy-digital/litex) by Enjoy Digital  
- [VSD FPGA Initiative](https://github.com/vsdip/vsdfpga_labs) by VLSI System Design (VSD)  
- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) from riscv-collab  



## Author

K M Skanda
