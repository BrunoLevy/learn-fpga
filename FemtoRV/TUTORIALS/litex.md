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

Synthetize
==========

Instructions to synthetize are different, depending on the board you have.

Instructions for ULX3S:
-----------------------
![](Images/ULX3S_SDRAM.jpg)

- determine FPGA variant: one of LFE5U-12F, LFE5U-25F, LFE5U-45F or LFE5U-85F
- determine SDRAM chip (see image): one of MT48LC16M16, AS4C32M16 or AS4C16M16
- plug the board
- synthethize and load design (in the command, replace FPGA variant and SDRAM chip with your own):
```
$ python3 -m litex_boards.targets.radiona_ulx3s --cpu-type=femtorv --build --load --device LFE5U-85F --sdram-module AS4C32M16
```

This will download the dependencies (including the latest version of
FemtoRV directly from its github repository, great !). It will also
compile the BIOS, synthesize the gateware and send it to the
device. If everything went well, you will see the colorful 'knight
driver' blinky of victory on the LEDs.


Instructions for ARTY:
----------------------
TODO, for symbiflow, use `--toolchain=symbiflow`.

Talk to the device
==================

Start a terminal emulator. You can use the one bundled with LiteX
(lxterm). You will need to determine on which port it is plugged (one
of `/dev/ttyUSBnnn`), use `$dmesg` right after plugging it (or try
different values). Supposing it is `ttyUSB0`, do:

```
  lxterm /dev/ttyUSB0
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

Coming next
===========

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

Graphics and HDMI
-----------------

SSD1331 OLED screen
-------------------
- Syntethize with `--with-oled` option.
- Generated include file for hw control registers: `build/radiona_ulx3s/software/include/generated/csr.h`
  (Many macros there to access SPI or to do bitbanging with control signals).
- In `litex-boards/litex_boards/targets/radiona_ulx3s.py`, oled uses standard `SPIMaster` module.
- control signals (RESET,CS,DC) are mapped to `"oled_ctl"` (which one is LSB ?)
- `"oled_ctl"` is defined in `litex-boards/litex_boards/platforms/radiona_ulx3s.py`: `dc,resn,csn`
- oled_ctl_out_write(), oled_spi_mosi_write() if using bitbanging
- Example of LiteX SPI usage in `litex/litex/soc/software/liblitesdcard/spisdcard.c`
- How to know which bit is (dc,resn,csn) in ctl ? Write cs, then read ctl !


```
void ssd1331_command(uint8_t cmd) {
   // how to specify command/data ? (dc) -> oled_ctl_out_write()
   oled_spi_cs_write(SPI_CS_LOW);
   oled_spi_mosi_write(byte);
   oled_spi_control_write(8*SPI_LENGTH | SPI_START);
   while(oled_spi_status_read() != SPI_DONE);
   oled_spi_cs_write(SPI_CS_HIGH);
}
```



Notes - LiteX cheatcodes and files
==================================
- simulation: `litex_sim --cpu-type=femtorv --with-sdram`
- ULX3S pins: `litex-boards/litex_boards/platforms/radiona_ulx3s.py`
- ULX3S: `litex-boards/litex_boards/targets/radiona_ulx3s.py`
- femtorv: `litex/litex/soc/cores/cpu/femtorv/core.py`
- bios: `litex/litex/soc/software/bios/main.c`
- framebuffer: `litex/litex/soc/cores/video.py`
