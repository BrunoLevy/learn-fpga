Example programs for LiteOS
---------------------------

This directory contains several examples to be used with LiteOS
(install LiteOS first, instructions [here](https://github.com/BrunoLevy/learn-fpga/tree/master/LiteX/software/LiteOS)).

Compile the programs: 
```
$ make
```
Then copy all `.elf` files to the SDCard. Connect to the SoC (`litex_term
/dev/ttyUSBnnn`), and verify that the programs are there:
```
liteOS> catalog
```

Now you can run the programs (for instance `hello.elf`):
```
liteOS> run hello.elf
```

The following programs are available:

|Program       | Description                                |
|--------------|--------------------------------------------|
|hello         | simplest program                           |
|spirograph    | draws animated patterns in the framebuffer |
|ST_NICCC      | port of an AtariST demo                    |
|tinyraytracer | port of Dmitry Sokolov's tiny raytracer    |
|imgui_test    | test program for Dear Imgui                |

ST_NICCC needs `scene1.dat` to be copied on the SDCard.

Creating your own program
-------------------------

Just create `my_program.c` or `my_program.cpp` and add `my_program.elf` to the list in the
`all:` target.

There are some libraries you can use
[here](https://github.com/BrunoLevy/learn-fpga/tree/master/LiteX/software/Libs).


How it works
------------

- the linker script [linker.ld](linker.ld) and the memory map [regions.ld](regions.ld):
  The linker script is very simple, it is similar to LiteX linker
  script, with the difference that it sends everything to `main_ram` (the SDRAM).
  The memory map declares `main_ram` 256KB after the actual address of
  the SDRAM, in order to leave it for FemtOS.
  
- the C runtime [crt0.S](crt0.S): it declares the global symbol
  `_start`, that does the following things: 
    - 1) save the context (all registers, except the snnn ones)
    - 2) initialize the `bss` segment to zero
    - 3) call `main`
    - 4) restore the context (saved registers)
    - 5) return to femtOS
    
- the memory allocator [sbrk.c](sbrk.c): it implements the low-levem
  system call used under the hood by `malloc()`. It is in fact quite
  simple, it just needs to keep track of the end of the heap.
    