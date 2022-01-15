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
- [Doom](Doom/): a port of Doom for LiteX
- [Tagl](Tagl/): a 3D software renderer (that I wrote in the 90s) ported to LiteX
- [Libs](Libs/): common libraries (ELF support, OLED screen, framebuffer, Dear ImGui port, stdio adapter)
