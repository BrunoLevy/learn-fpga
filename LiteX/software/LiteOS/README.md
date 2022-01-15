LiteOS
------

LiteOS is a super minimalistic operating system for LiteX SoCs. It has
two commands:
- `catalog <dir>`: lists the files on the SDCard
- `run <filename.elf>`: runs a program
It optionally has two additional commands to switch the framebuffer
and the ESP32 on and off:
- `esp32 <on|off>`
- `framebuffer <on|off>`

Step 1: compile
---------------
```
$ make LITEX_DIR=<path where you synthesized LiteX>
LEARN_FPGA_DIR=<path where you installed learn-fpga> LITEX_PLATFORM=<platform>
```
(platform corresponds to your FPGA board, it can be for instance radiona_ulx3s).

Alternatively, you can edit `Makefile` and hardwire `LITEX_DIR`, `LEARN_FPGA_DIR` and `LITEX_PLATFORM`.

If everything goes well, this will generate `boot.bin`.

Step 2: install
---------------
Copy `boot.bin` on a FAT32 formatted SDCard. Insert the SDCard in the
slot of your FPGA board.

Step 3: run
-----------
Reboot the board. The LiteX BIOS automatically finds `boot.bin` on the
SDCard and loads it. Connect to it using `lxterm /dev/ttyUSBnnn` where
`nnn` depends on the circumstances (it is 0 in most cases). If everything
went well, you will see the LiteOS prompt.

```
LiteOS>
```

Now type `help` to have the list of available commands. In addition to
`catalog` and `run`, there may be additional commands:

- if you have an ULX3S, there is an `esp32` command to switch the
on-board SoC on and off. It is useful because you can install
MicroPython on it, and use it to send files on the SDCard through Wifi 
(more confortable than removing the SDCard, copying the files on it,
re-inserting the SDCard, and less risks of damaging the connector
if you do that multiple times). It is necessary to switch the ESP32 on
and off, because only one of the FPGA and ESP32 can access the SDCard
at a time.

How it works
------------

The idea behind LiteOS is to provide the bare necessary
functionalities while writing as little code as possible.
LiteX libraries already have nearly everything necessary. The main
missing component that I needed to create is:

- a loader for the ELF format. I wrote a super
simple one [here](https://github.com/BrunoLevy/learn-fpga/blob/master/LiteX/software/Libs/lite_elf.c).
The technical details are described [here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/software.md).
The result is a few hundred lines of with no dependencies that can directly load statically-linked ELFs.

Then the rest works as follows:

- the Makefile: I created a [makefile.inc](https://github.com/BrunoLevy/learn-fpga/blob/master/LiteX/software/makefile.inc),
  included by all my LiteX software projects, that selects the right compiling options, and that can pull dependencies
  from LiteX libraries.

- the C runtime (crt0.S): I reuse the one from LiteX directly.

- the [linker script](linker.ld), mainly copied from LiteX's default
one, with a couple of differences: we are not going to use the ROM and
the SRAM, all program segments are sent to the SDRAM. The C runtime
(crt0.S) in LiteX copies initialized variables from the ROM 
(_fdata_rom ... _edata_rom) to the RAM (_fdata ... _edata). Here we
do not need to do that, and set all the corresponding symbols to 0
(then the corresponding loop in crt0.S does nothing).


- the command line: the LiteX BIOS already has a nice system for 
command line editing, history and autocompletion, so I reuse it !
To do that, there is a special `commands` section declared in 
the linker script like in the BIOS. Then the `define_command()`
macro works like in the BIOS and we can reuse it directly !

- our new commands: they are declared in the [builtins.c](builtins.c)
file. There are optional commands to switch the framebuffer and the
ESP32 on and off, and the two commands `catalog` to list files on the
SDCard, and `run` to execute an ELF stored on the SDCard.
