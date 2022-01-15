LiteX Instructions for ULX3S:
-----------------------------
![](Images/ULX3S_SDRAM.jpg)

- determine FPGA variant: one of LFE5U-12F, LFE5U-25F, LFE5U-45F or LFE5U-85F
- determine SDRAM chip (see image): one of MT48LC16M16, AS4C32M16 or AS4C16M16

_Note: there exists variants of the ULX3S equipped with a IS42S16160G
SDRAM chip. For this one, use `--sdram-module MT48LC16M16` 
(thank you @darkstar007)._

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

