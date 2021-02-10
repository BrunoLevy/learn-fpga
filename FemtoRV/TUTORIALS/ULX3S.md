ULX3S Tutorial
==============

![](Images/ULX3S.jpg)

This tutorial will show you how to install FPGA development tools,
synthesize a RISC-V core, compile and install programs and run them
on a ULX3S.

Install open-source FPGA development toolchain
==============================================
Before starting, you will need to install the open-source FPGA
development toolchain (Yosys, NextPNR etc...), instructions to
do so are given [here](toolchain.md).

(Optional) Configure femtosoc and femtorv32
============================================
Time to edit `learn-fpga/FemtoRV/RTL/CONFIGS/ulx3s_config.v`. 
This file lets you define what type
of RISC-V processor you will create, and which device drivers in the
associated system-on-chip. By default the small OLED screen is
configured. It does not harm, but you can comment-out the corresponding
line if you do not have it (`SSD1331`), more on this below.

Synthetizing
============
You can now compile the firmware, synthesize the design and send it to
the device. Plug the device in a USB port, then:
```
$make ULX3S
```
The first time you run it, it will download RISC-V development tools (takes a while).
The default firmware includes a file browser, that can load `elf`
executables stored on an SDCard. If you have the small OLED screen
plugged, then you will see a message indicating that the SDCard was
not found. You can also plug a monitor to the not-HDMI connector. 
My (crappy) OS is made possible by
@ultraembedded's [fat io lib](https://github.com/ultraembedded/fat_io_lib),
a wonderful piece of software that lets you read files from a
fat-formatted medium. In a near future I'll add a command-line version.

Example programs
================
The directories `FIRMWARE/EXAMPLES` and `FIRMWARE/ASM_EXAMPLES` contain programs in C and assembly
that you can run on the device. 

To compile a program:
```
$cd FIRMWARE/EXAMPLES
$make program.elf
```
(to compile all examples, use `make everything`), then copy all the
`.elf` files to a FAT-formatted micro SDCard, insert it into the
ULX3S, reset the ULX3S using the fire button that is above the SDCard.

Now you can browse using the `up` and `down` buttons, and run the
selected program using the `right` button. To exit a program, reset
the device using the `reset` button (above the SDCard).


There are several C and assembly programs you can play with (list below). To learn more about RISC-V assembly,
see the [RISC-V specifications](https://riscv.org/technical/specifications/), 
in particular the [instruction
set](file:///tmp/mozilla_blevy0/riscv-spec.pdf) and the [programmer's
manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md).

ASCII-art version of the Mandelbrot set, computed by a program in
assembly (`ASM_EXAMPLES/mandelbrot_terminal.S`)
![](Images/mandelbrot_terminal.gif)

| Program                                | Description                                                    |
|----------------------------------------|----------------------------------------------------------------|
| `ASM_EXAMPLES/blinker_shift.S`         | the blinker program, using shifts                              |
| `ASM_EXAMPLES/blinker_wait.S`          | the blinker program, using a delay loop                        |
| `ASM_EXAMPLES/test_serial.S`           | reads characters from the serial over USB, and sends them back |
| `ASM_EXAMPLES/mandelbrot_terminal.S`   | computes the Mandelbrot set and displays it in ASCII art       |
| `EXAMPLES/hello.c`                     | displays a welcome message                                     |
| `EXAMPLES/sieve.c`                     | computes prime numbers                                         |


Graphics
========

Let us do some graphics. For this, you have two options:
- the FGA (Femto Graphic Adapter) is a graphic board, that outputs
  video to the HDMI connector of the ULX3S,
- connect a small OLED display to the `OLED1` connector of the ULX3S.

These options can be selected in `RTL/CONFIGS/ulx3s_config.v`. You can
activate both if you want. If both are activated, the firmware mirrors 
what's displayed on the OLED display and sends it through HDMI. 

FGA (Femto Graphic Adapter)
---------------------------

The Femto Graphic Adapter supports the following mode:

| Mode          | Description                        |
|---------------|------------------------------------|
| 320x200x16bpp | 65536 colors, RGB                  |
| 320x200x8bpp  | 256 colors, colormapped, two pages |
| 640x400x4bpp  | 16 colors, colormapped             |


It supports hardware-accelerated `FILLRECT` operation, 
also used to clear the screen, and to draw scanlines in
polygon fill (it is 7 times faster than a software loop).

OLED screen
-----------
It is not mandatory, but it is cool to add a small OLED display. You
got two options, SSD1331 (top image row below) or SSD1351 (bottom image row),
both are supported by the hardware/firmware (activate `NRV_IO_SSD1351`
or `NRV_IO_SSD1331` in'RTL/CONFIGS/ulx3s_config.v'). 

![](Images/SSD1331_on_ULX3S.jpg)
_SSD1331 OLED display, mechanically fits well on the ULX3S_
![](Images/SSD1351_on_ULX3S.jpg)
_SSD1351 OLED display (larger screen), connected to the ULX3S with wires_


Which one should I use ? Here is a side-by-side comparizon to help you:

 |        SSD1351                |            SSD1331             |
 |-------------------------------|--------------------------------|
 |  +A large tiny screen !       |  -A bit too tiny               |
 |  -Needs wires on the ULX3S    |  +Fits well on a ULX3S         |
 |  -Cannot flip/rotate          |  +Flexible configuration       |
 |  -Nearly no accel. primitives |  +HW accel fillrect,scroll,copy|
 
- For both: luminous and crisp rendering, much better than LCD !
- For both: last but not least, supported by FemtoRV32/FemtoSOC !!

Then my recommendation is SSD1331 for ULX3S (and SSD1351 for other
boards). The main reason is that mechanically, SSD1331 fits very
well with the ULX3S. You will need to solder header pins to the ULX3S
(or ask a skilled friend, which is what I did, thank you @ssloy !!!).
On the SSD1331, you can solder a female header, as shown on the
top row images (my 14 years old son Nathan did the soldering, 
he is good !). For the SSD1351, connect the wires according to the names
on the ULX3S and the names on the display. Note that the pin names may
vary a bit, refer to this table:

| pin name on the ULX3S | pin description      | other possible names on the display |
|-----------------------|----------------------|-------------------------------------|
|  CS                   | Chip Select          |                                     |
|  DC                   | Data/Command         |                                     |
|  RES                  | Reset                | RST                                 |
|  SDA                  | Data                 | DIN                                 |
|  SCL                  | Clock                | CLK                                 |
|  VCC                  | +3.3V                |                                     |
|  GND                  | Ground               |                                     |
             

If you removed it from the configuration, do not forget to edit
`RTL/CONFIGS/ulx3s_config.v` and uncomment the line with `NRV_IO_SSD1331`
or `NRV_IO_SSD1351`, then re-synthethise and send to device using:
`make ULX3S` in the `FemtoRV32` directory.

Let us compile a test program:
```
$ cd FIRMWARE/examples
$ make gfx_test.elf
```

Copy it to the SDCard, insert it in the ulx3s, restart the device, and
start the program.

If everything goes well, you will see an animated colored pattern on
the screen. Note that the text-mode demos (`hello.c` and `sieve.c`)
still work and now display text on the screen. There are other
programs that you can play with:

![](Images/IceStick_graphics.jpg)
![](Images/ULX3S_demos.jpg)
_(The black diagonal stripes are due to display refresh, they are not visible normally)._

| Program                                      | Description                                                                      |
|----------------------------------------------|----------------------------------------------------------------------------------|
| `ASM_EXAMPLES/test_OLED.S`                   | displays an animated pattern.                                                    |
| `ASM_EXAMPLES/mandelbrot_OLED.S`             | displays the Mandelbrot set.                                                     |
| `EXAMPLES/cube.c`                            | displays a rotating 3D cube.                                                     |
| `EXAMPLES/mandelbrot.c`                      | displays the Mandelbrot set (C version).                                         |
| `EXAMPLES/riscv_logo.c`                      | a rotozoom with the RISCV logo (back to the 90's).                               |
| `EXAMPLES/spirograph.c`                      | rotating squares.                                                                |
| `EXAMPLES/gfx_test.c`                        | displays an animated pattern (C version).                                        |
| `EXAMPLES/gfx_demo.c`                        | demo of graphics functions(old chaps, remember EGAVGA.bgi ?).                    |
| `EXAMPLES/test_font_OLED.c`                  | test font rendering.                                                             |
| `EXAMPLES/sysconfig.c`                       | displays femtosoc and femtorv configurations.                                    |
|                                              |                                                                                  |
|_Larger ones (that would not fit on IceStick)_|                                                                                  |
| `EXAMPLES/imgui_xxxx.c`                      | some ports from [ImGui challenge](https://github.com/ocornut/imgui/issues/3606). |
| `EXAMPLES/mandelbrot_float_OLED.c`           | displays the Mandelbrot set (floating-point version, using gcc's software FP).   |
| `EXAMPLES/tinyraytracer.c`                   | a port from [TinyRaytracer](https://github.com/ssloy/tinyraytracer).             |

The LIBFEMTORV32 library includes some basic font rendering, 2D polygon clipping and 2D polygon filling routines. 

File access on the SDCard
=========================

Once again, @ultraembedded's [fat io lib](https://github.com/ultraembedded/fat_io_lib) 
is really an awesome piece of software. In a couple of `.c` files, it provides a
self-contained library and implementations of `fopen()`, `fread()`,
`fwrite()` and `fclose()`. Let us see how to use that to port a 
[Y2K demo called ST-NICCC](http://www.pouet.net/prod.php?which=1251).
The demo uses a precomputed stream of 2D polygons stored in a file.
To generate the demo, first copy the file `FIRMWARE/EXAMPLES/DATA/scene1.dat` 
(from the original ST-NICCC demo) to the SDCard. Then generate the
executable:
```
$ cd FIRMWARE/EXAMPLES
$ make ST_NICCC.elf
```
then copy `ST_NICCC.elf` to the SDCard, insert the SDCard in the ULX3S
and restart it, then select `ST_NICCC.elf` using the up/down buttons and
start it using the right button.

_Note: there is also a version `ST_NICCC_spi_flash.c` that reads data
from the SPI Flash (the same component that stores the FPGA
configuration in which there is sufficient room to store additional
data). It is used by the IceStick version. It works also on the ULX3S
(see instructions in the source)._

More about not-HDMI and FGA (Femto Graphics Adapter)
====================================================

There are several programs that you can use, in `FIRMWARE/EXAMPLES`:

| Program                                      | Description                                                                      |
|----------------------------------------------|----------------------------------------------------------------------------------|
| `EXAMPLES/test_FGA.c`                        | Displays an animated colored pattern.                                            |
| `EXAMPLES/tinyraytracer.c`                   | A port from [TinyRaytracer](https://github.com/ssloy/tinyraytracer).             |
| `EXAMPLES/ST_NICCC.c`                        | A port of the ST_NICCC demo                                                      |

Compile them by `cd FIRMWARE/EXAMPLES` then `make xxx.elf` where `xxx` is the name of the program. Copy the generated `.elf` executable to
the SDCard. Plug the HDMI monitor to the ULX3S. Select the program using the up and down buttons, run it with the right button. The button
near the SDCard is the reset button.

If you want to write your own programs, it is very easy, just use `FGA_setpixel(X,Y,R,G,B)` where `X` and `Y` are the coordinates
(resolution is 320x200) and `R`,`G`,`B` the color components, each in 0..255.

If you want to do animations, you may need to directly write to the graphic memory.
Graphic memory starts at address `FGA_BASEMEM`. Each pixel is encoded in 16 bits.
The macro `GL_RGB` encodes a pixel from its r,g,b components (each of them between 0 and 255).
The `FGA_setpixel` function is written as follows: 
```
static inline FGA_setpixel(int x, int y, uint8_t R, uint8_t G, uint8_t B) {
  ((uint16_t*)FGA_BASEMEM)[320*y+x] = GL_RGB(R,G,B);
}
```
It tells you everyhting you need if you want to implement your own optimized graphic primitives.
The GL_RGB macro shifts and combines the components. It uses the same encoding as for the small OLED screen.

Epilogue
========

MORE TO COME / TO BE CONTINUED (with a cleaner FemtOS, priviledged instructions, system calls,
floating-point instructions, PS/2 mouse and keyboard, ImGui port...)