Ice4pi Tutorial
=================


The [ice4pi open-source KiCAD project](https://github.com/lightside-instruments/ice4pi) of a Raspberry Pi shield is based on the design of IceStick.

Ideally a bitstream and firmware for IceStick will work for ice4pi.

![](Images/ice4pi.jpg)

There are few exceptions (the IrDA transceiver is removed as well as the unpopulated side connectors).

It obviously has added 40-pin Raspberry Pi connector interface with all IO pins connected to the available FPGA IOs. Which enables you to interact with Raspberry Pi shields and the Raspberry Pi itself.

The SPI Flash programming interface is connected to the Raspberry Pi interface. This allows you to reload and restart the logic on the shield without rebooting the Pi.
The Serial TX/RX pins are connected to the Raspberry Pi interface too.

You can extend the open-source KiCAD design and use the board as base for your own design.

This tutorial is short because it only documents the differences between the ice4pi and IceStick boards. Those are kept to a minimum intentionally.

In short for building the project you will use 'make ICE4PI'
instead of 'make ICESTICK'

For loading you would not use iceprog but a script based on the flashprog tool. The script is included TOOLS/ice4pi_prog

Here is the command sequence I use to build the SoC
and compile the hello C program. Then load them
to the shield.

```
make ICE4PI
cd FIRMWARE/EXAMPLES
make hello.spiflash.bin
cd ../../
sudo TOOLS/ice4pi_prog femtosoc.bin FIRMWARE/EXAMPLES/hello.spiflash.bin
```

There is 1 difference of significance in the BOM for the ice4pi-2.4-1 version:

- The SPI flash chip used on IceStick is N25Q032A13ESC40F while the one used
on ice4pi-2.4-1 is W25Q32JVSNIQ. In later revisions there is no difference.


Now with this in mind you can go through the detailed [ICESTICK tutorial](ICESTICK.md) !
