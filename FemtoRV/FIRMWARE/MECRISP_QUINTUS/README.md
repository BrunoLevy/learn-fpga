Mecrisp-quintus forth environment for IceStick
==============================================

This directory contains the bitstream for the mecrisp-quintus forth
environment, ported to FemtoRV32 by Matthias Koch, the author of
mecrisp.

Mecrisp is licensed under GPLv3. Refer to [mecrisp website](http://mecrisp.sourceforge.net/)
for sources and more information.

What follows is a minitutorial.

Step 1: Synthetize FemtoRV and FemtoSOC for mecrisp-quintus
-----------------------------------------------------------
Synthetize femtorv32 (configured for mecrisp quintus) and send it to
the IceStick:
```
$ cd learn_fpga/FemtoRV32
$ make ICESTICK_MECRISP_QUINTUS
```

Step 2: Program
---------------
Send mecrisp-quintus to the SPI flash of the IceStick
```
$ cd FIRMWARE/MECRISP_QUINTUS/
$ iceprog -o 64k mecrisp-quintus-hx1k-with-disassembler.bin
```

Step 3: It's alive !
--------------------
Connect to it with a terminal (you will need to install `picocom`).
```
$ cd learn_fpga/FemtoRV32
$ make terminal_picocom
```
(it works also with other terminals, but picocom has more
functionalities).

Picocom hotkeys

| Key                  | Function        |
|----------------------|-----------------|
|`<ctrl><a> <ctrl><t>` | reset femtorv32 |
|`<ctrl><a> <ctrl><x>` | exit picocom    |

Try some forth commands and debugger:
```
words
3 6 + .
see +
3 6 step +
0 leds
5 leds
15 leds
```

_I must admit I do not know how to do more, it is a shame !_ I need
to learn Forth, it is a wonderful language, minimalistic and elegant.
Look: the environment, commands, compiler, assembler simulator fits
in 64k, amazing ! Would be great to pack in there a couple of nice demos
(and we got nearly 4MB of flash for that !!).

Links
-----
- [mecrisp website](http://mecrisp.sourceforge.net/)
- [Forth tutorials](https://www.forth.com/starting-forth/)
