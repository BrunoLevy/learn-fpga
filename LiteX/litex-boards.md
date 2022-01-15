LiteX Instructions
------------------

First thing to do is determining whether LiteX supports your board,
and what is the name of the configuration file:
```
 $cd <your local installation of LiteX>
 $ls litex-boards/litex_boards/targets/
```

For instance, if you have an OrangeCrab, there is a file named `gsd_organgecrab.py`.
Then you need to learn more about LiteX options for your board. Still
supposing OrangeCrab, you can do:

```
 $cd learn-fpga/LiteX
 $python3 -m litex_boards.targets.gsd_orangecrab --help

```

Most options are common to all boards. What may differ from one board
to another is the installed FPGA, that can come in different sizes.
For instance, for the OrangeCrab, with the `--device` option, you can
specify whether you have a 25F or 45F ECP5 (use a magnifying loop on
your board to make sure). Second thing that may vary is the SDRAM
chip. For instance, for OrangeCrab there is a `--sdram-device` option.

Then you can generate the bitstream. Here is an example of a
commandline for an OrangeCrab (you'll need to make it match your
own configuration).
```
 $python3 -m litex_boards.targets.gsd_orangecrab --cpu-type femtorv --cpu-variant petitbateau --build --load --device 25F --sdram-device MT41K64M16 --ecppack-compress --with-spi-sdcard
```

There are several flags that are common to all boards:
- `--cpu-type` and `--cpu-variant`: you can select among SERV
   (smallest RISC-V CPU), FemtoRV (easy-to-understand), PicoRV (the
   reference), VexRiscV (maximum performance) and many others.
- `--load`: load bitstream to FPGA
- `--toolchain`: specify FPGA toolchain (Yosys+NextPNR, symbiflow ...). For ARTY, use `--toolchain symbiflow` 
