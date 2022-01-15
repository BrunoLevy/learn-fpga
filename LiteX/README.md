LiteX
=====

FemtoRV can be used with LiteX.

[LiteX](https://github.com/enjoy-digital/litex) is an easy-to-use
framework for creating SoCs.
- it supports many different FPGA boards
- it includes gateware for many different devices (SDRAM, HDMI, SDCard,
  SATA ...)
- it has basic software support (a BIOS)
- with some cores (VexRiscV) it can even run Linux (not possible with FemtoRV though)

The remainder of this file contains the instruction to install LiteX
and its dependencies.


Install open-source FPGA development toolchain
==============================================

Before starting, you will need to install the open-source FPGA
development toolchain (Yosys, NextPNR etc...), instructions to
do so are given [here](toolchain.md).


Install LiteX
=============

Follow setup instructions from [LiteX website](https://github.com/enjoy-digital/litex#quick-start-guide)

*TL;DR*

```
$ mkdir LiteX
$ cd LiteX
$ wget https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
$ chmod +x litex_setup.py
$ ./litex_setup.py --init --install --user 
$ pip3 install meson ninja
$ ./litex_setup.py --gcc=riscv
```

Synthesize
==========

Instructions to synthesize are different, depending on the board you have.

- [ULX3S](ULX3S.md)
- [Other boards](litex-boards.md)

Connect to the SoC
==================

Start a terminal emulator. You can use the one bundled with LiteX
(lxterm). You will need to determine on which port it is plugged (one
of `/dev/ttyUSBnnn`), use `$dmesg` right after plugging it (or try
different values). Supposing it is `ttyUSB0`, do:

```
  $lxterm /dev/ttyUSB0
```

Then press `<enter>`. You will see the `litex>` prompt.

- As you may have guessed, do `litex> help` to see the possible commands.
- Try `litex> sdram_test`. If everything went well, it should say `Memtest OK`.
- To exit, press `<ctrl><\>`

FemtoRV variants
================
LiteX can use all the variants of FemtoRV, from the tiniest: femtorv-quark (RV32I) to
the bigest one with an FPU: femtorv-petitbateau (RV32IMFC+irq).

|variant     | instruction set |
|------------|-----------------|
|quark       | RV32I           |
|electron    | RV32IM          |
|intermissum | RV32IM+irq      |
|gracilis    | RV32IMC+irq     |
|petitbateau | RV32IMFC+irq    |

```
$ python3 -m litex_boards.targets.radiona_ulx3s --cpu-type=femtorv --cpu-variant=petitbateau --build --load --device LFE5U-85F --sdram-module AS4C32M16
```

Software
========

Time to [compile and install software](https://github.com/BrunoLevy/learn-fpga/tree/master/LiteX/software)
on your SoC. 

Compiling RiscV software for the device
---------------------------------------
See LiteX demo [here](https://github.com/enjoy-digital/litex/tree/master/litex/soc/software/demo)

```
$ cd <LiteX installation directory>
$ litex_bare_metal_demo --build-path build/radiona_ulx3s/
```

Sending software to the device
------------------------------
lxterm can be used to send a binary to the device, as follows:
```
$lxterm --kernel <software.bin> --speed 115200 /dev/ttyUSB0
```

Notes - LiteX cheatcodes and files
==================================

If you want to learn more about how LiteX works, reading the
sourcecode is a good idea ! Some important links and files:

- simulation: `litex_sim --cpu-type=femtorv --with-sdram`
- ULX3S pins: `litex-boards/litex_boards/platforms/radiona_ulx3s.py`
- ULX3S: `litex-boards/litex_boards/targets/radiona_ulx3s.py`
- femtorv: `litex/litex/soc/cores/cpu/femtorv/core.py`
- bios: `litex/litex/soc/software/bios/main.c`
- framebuffer: `litex/litex/soc/cores/video.py`
- [wishbone-utils](https://github.com/litex-hub/wishbone-utils/releases)
