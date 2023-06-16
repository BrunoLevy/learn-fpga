LiteX Instructions for OrangeCrab:
----------------------------------

Before starting:

Make sure you have updated `udev rules` to allow accessing the USB port of the OrangeCrab in
user mode, as explained [https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/toolchain.md#orangecrab-ecp5](here).

Synthesize and program:
```
$ cd learn-fpga/LiteX
$ python3 -m litex_boards.targets.gsd_orangecrab --device 25F --cpu-type femtorv --cpu-variant gracilis --with-spi-sdcard --build --load --ecppack-compress
```
(replace `25F` with the one in your device (there is also a `45F` and a `85F` version).

Build software:
Edit `software/makefile.inc`
- set `LITEX_DIR` and `LEARNFPGA_DIR`
- set  `LITEX_PLATFORM` to `gsd_orangecrab` 
```
$ cd software/LiteOS
$ make
$ cd ../Programs
$ make hello.elf
```

Copy `LiteOS/boot.bin` and `Programs/hello.elf` to a SDCard
Insert the SDCard in the OrangeCrab

```
$ litex_term /dev/ttyACM0
$ reboot
```

This should load LiteOS from the SDCard

Run a simple program:
```
liteOS> run hello.elf
```