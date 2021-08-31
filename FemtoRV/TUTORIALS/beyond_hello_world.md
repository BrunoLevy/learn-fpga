Hello, world ... what's next ?
==============================

OK, you are happy, you designed a RISC-V core, ran it in Verilator,
synthetized it and sent it to the device, and it seems to do something.
Well, what could we do with it now ? 

Tinyraytracer
=============

My friend Dmitry Sokolov wrote a nice self-contained raytracing program 
called [Tinyraytracer](https://github.com/ssloy/tinyraytracer) for his 
computer graphics course. It is an interesting program to be run on 
your own risc-v core, because:
- it generates nice images
- it tests many functionalities of your core (a good testbench)
- it can be compiled with different instruction sets, from the
  bare RV32I used by the tiny femtorv32-quark to the full-fledged
  RV32IMFC femtorv32-petitbateau (with hardware that floats). 
  
The original tinyraytracer is written in C++. Since pulling the C++
runtime may be a bit too much for the tiniest cores, I ported it to
plain C. my version is available [here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/FIRMWARE/EXAMPLES/tinyraytracer.c).

If you want to use it for your own core, you will need to change three
things:

| Function                        | Description                                        |
|---------------------------------|----------------------------------------------------|
| `graphics_width`                | a macro that gives the screen width in pixels      |
| `graphics_height`               | a macro that gives the screen height in pixels     |
| `graphics_init()`               | a function that start graphic mode                 |
| `graphics_set_pixel(x,y,r,g,b)` | x,y are ints, r,g,b are floats between 0.0 and 1.0 |
| `graphics_terminate()`          | called at the end. Leave empty if not needed.      |

In addition, if your core has a tick counter, to display the elapsed time, you may define
the following functions (leave their bodies empty if you do not need them)

| Function              |
|-----------------------|
| `stats_begin_frame()` | 
| `stats_begin_pixel()` |
| `stats_end_pixel()`   |
| `stats_end_frame()`   |

These functions are meant to collect timings. You can leave them empty if you do not need
them. Timings are collected pixel by pixel, because on some small cores (femtorv32-quark), the
clock tick counter is smaller (24 bits), and wraps during rendering of a frame. 

Compiling
=========
See [this tutorial](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/software.md)
for more information on how to compile RISC-V software for your own core.
