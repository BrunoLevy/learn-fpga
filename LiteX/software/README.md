Software for LiteX SoCs
-----------------------

This directory contains libraries and software packages for LiteX SoCs:
- [DemoBundle](DemoBundle/): a ROM with several demo programs, to
    measure the speed of softcores (raystones), to draw shiny spheres
    with raytracing (tinyraytracer), to display animations on the
    small OLED screen (riscv-logo, julia) ...
- [LiteOS](LiteOS/): a minimalistic OS that lets you load and execute
    programs (ELF binaries) stored on the SDCard;
- [Programs](Programs/): simple example programs for LiteOS
- [Doom](Doom/): a port of Doom for LiteOS
- [Tagl](Tagl/): a 3D software renderer (that I wrote in the 90s) ported to LiteOS
- [Libs](Libs/): common libraries (ELF support, OLED screen, framebuffer, Dear ImGui port, stdio adapter)


Links, stuff to port
--------------------

- [dos-like](https://github.com/mattiasgustavsson/dos-like)
- [tiny-gl](https://github.com/C-Chads/tinygl)
- [tcc-riscv](https://github.com/sellicott/tcc-riscv32)
- [Bubble Universe](https://stardot.org.uk/forums/viewtopic.php?t=25833&sid=33182a6ffa6f84b08bb6f52cae2ad35d)