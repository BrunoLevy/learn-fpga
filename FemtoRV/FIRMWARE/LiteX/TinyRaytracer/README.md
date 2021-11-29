Raytracing firmware for LiteX
=============================

This directory contains a C version of Dmitry Sokolov's [tinyraytracer](https://github.com/ssloy/tinyraytracer), adapted to LiteX.
It can be used to benchmark different cores running on LiteX.
Raytracing is an interesting operation for benching cores, because it
uses massively the floating point operations. 

Step 0: synthethize
-------------------
Follow the instructions [here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/litex.md).
If you have the small OLED display plugged on the ULX3S (reference `SSD1331`), 
you can add the `--with-oled` option to the command line. 

Step 1: compile
---------------
```
$ make BUILD_DIR=<path where you synthesized LiteX> 
```
(for instance, `LiteX/build/radiona_ulx3s`). 

Alternatively, you can edit `Makefile` and hardwire `LITEX_DIR` and `LITEX_PLATFORM`.

If everything goes well, this will generate `demo.bin`.

Step 3: execute
---------------

```
$ lxterminal --kernel demo.bin /dev/ttyUSBnn
litex> reboot
litex-raytracing> tinyraytracer
```
This will display the result in the terminal window (with BIG pixels
!). This is text mode, with escape sequences to change the background
color. If you have the small OLED display plugged in and configured, 
you will see also the image on it. 

Alternatively, you can use:
```
litex-raytracing> raystones
```
This will compute the image without rendering in the terminal
(rendering in the terminal takes time for some reasons, and if you 
want to compare the performances of cores, you want timings that are
as precise as possible).

Performance is measured in "raystones", i.e. pixels per seconds per
MHz (not an official unit !).

If you test multiple cores, do not forget to recompile the software:
```
$ make clean all
```

Compilation flags are adapted to the configured core (for instance,
RV32I, RV32IM, RV32IMC, RV32IMFC ...). If it crashes, it may be 
because you executed code compiled with flags that are not supported
by the configured core (for instance, play with femtorv32-petitbateau
that supports RV32IMFC, then switch to femtorv32-quark but load the
software that was compiled for petitbateau).
