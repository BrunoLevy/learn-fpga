Software and compilers for RISC-V
=================================

_What would have helped me if somebody had told me right from the
beginning._

The RISC-V gcc compilers
------------------------

RISC-V exists in different 'flavors', first the base integer
instruction set (RV32I). It has optional extensions: multiplications
and divisions (M), single-precision and double-precision floating
points (F,D), atomic instructions (A). 

The compiler to be used depends of course of which instructions are
supported by the processor (Note: it is also possible to _emulate_ 
instructions by catching illegal instructions in an exception handler
and doing the instruction's work in software, but exceptions are not
supported yet by FemtoRV32). In our case we will need a compiler
targeting RV32I or RV32IM depending on what is configured in
`RTL/femtosoc_config.v` (on the IceStick can't be anything else than
RV32I). In the future, I plan to implement support for F, and maybe D.

There is also something else to be known about RISC-V gcc compilers
(that took me some time to understand). Besides the targeted instruction set, 
gcc also exists in two different
flavors, depending on whether they target a Linux system
(then GCC is called `riscv64-linux-gnu-gcc`) or a microcontroller
(`riscv64-unknown-elf-gcc`). All the executable of the toolchain start
with the same prefix. Note that the prefix starts with `riscv64`,
but the toolchain supports both 32 bits riscv target (that we are using) 
and 64 bits.

In our case we need a compiler for microcontrollers (FemtoRV32 is not
Linux-capable yet). The packages generally available in Linux distributions are
targeting a Linux system, so we cannot use them directly (still possible
for baremetal firmwares, but not for generating 
FemtoRV32 compatible elf, more on this below). It is also a good thing 
to have all the possible combinations of `RV32I(M)(A)(F)(D)` installed, 
if you want to play with different core configurations, and implement a 
FPU in Verilog, or in an exception handler.

Some precompiled toolchains are available in SIFIVE's website, 
[here](https://static.dev.sifive.com/dev-tools/riscv64-unknown-elf-gcc-8.3.0-2020.04.0-x86_64-linux-ubuntu14.tar.gz).
They can be used directly under Linux or Windows 10/WSL. FemtoRV32's Makefile (`FIRMWARE/makefile.inc`) automatically 
downloads it. It is a big package (300Mb or so), but then you have all
possible combination of instruction sets, and more importantly, the
associated libraries. It is important, because for instance, if you use RV32I, then
you do not have hardware multiplication. You need both a function for
that (link with the right gcc library) and you need to tell the
compiler to generate a call to that function instead of a `MUL`
instruction. It also concerns all the floating point operations, that
can be either implemented by using integer multiplication, or calling
the software version. There are many combinations. This is what you 
chose at the beginning of `FIRMWARE/makefile.inc`, by setting
`ARCH` (to `rv32i` or `rv32im` for now, but everything is ready for
all the other extensions, such as `c`,`a`,`f`...).

_If you want to know more / to have an even more baremetal approach:_

It is also possible to use gcc to only produce object `.o` files and then
use `ld` to link with a library that implements the needed functions
(instead of using the standard C runtime). If you do that, it will work
even if your compiler is targeted towards a Linux runtime (because you
do not use the C libraries). This is what I was doing at the beginning, 
however I do not recommend to do that, because everything gets painful
(need to reinvent the wheel, to reimplement memcpy() etc..., and there
is no floating point). If you really want to do that, take a look at `FIRMWARE/LIBFEMTOC/Makefile`, 
uncomment `MISSING_OBJECTS` and `MISSING_OBJECTS_WITH_DIR`. If you want to 
learn more about how this works and how to find these functions, the sources for the toolchain and
libraries are [here](https://github.com/riscv/riscv-gnu-toolchain).
I found the sources for the multiplication function here:
`riscv-gcc/libgcc/config/riscv/muldi.S`. Note that it is the same
function for 64-bits (`muldi`) and 32-bits (`mulsi`) multiplication,
with a macro to select the right one. Division and modulo are in the
same directory. 
Another interesting function you will find there is the C runtime
startup function: `riscv-newlib/libgloss/riscv/crt0.S`. It is good to
see it, because for when we will run elf executables, we know what the
C runtime expects from us.

Producing a RISC-V executables: bare metal ELF and standard ELF
---------------------------------------------------------------

By default, gcc produces executables in the ELF format (Executable and
Linkable Format). Now we want to convert it into something we can load
in our risc-v processor on the FPGA. There are two different ways of
doing that (and we will do both):

  1) convert the ELF executable into `FIRMWARE/firmware.hex`, an ascii
file in hexadecimal, that can be directly loaded by Verilog's `readmemh()` 
function to initialize the RAM, as done in `RTL/femtosoc.v`. This
solution is used by the smaller devices (IceStick), that do not have
SDCard reader or that have not enough RAM.

  2) use the ELF executable as is, copied on an SDCard, and start the
program using a minimalistic/crappy OS (FemtOS). Note that this solution
requires to have the OS preloaded in the RAM (this is why we need both 
solutions).


Bare metal ELF
--------------

Let us start to take a deeper look at solution 1). In fact, there is
also something important that we need: by default, gcc will produce 
an executable with a certain memory map, that does not necessarily 
fits our need. For instance, the text segment starts at address 
`0x10000` (=64kb). We do not even have this quantity of RAM on the IceStick. 
Note that it would be possible to wire the address decoder in `femtosoc.v` 
in such a way that RAM artificially starts at this address, but it is 
also possible to tell gcc to use a different memory map. To do so, I am
using a linker script, in `FIRMWARE/CRT_BAREMETAL/femtorv32.ld`, with
the following contents:
```
MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x40000
}
SECTIONS
{
    .text :
    {
        crt0.o (.text) 
        *(.text)
    }
}
```
_Disclaimer: I do not fully understand what I'm doing here, linker
scripts seem to be a scientific discipline on its own, but at least
what I've done here seems to fit my needs !_

In the same directory, there is also `crt0.S`, my function to initialize the C
runtime, that replaces gcc's default one:
```
.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li gp,IO_BASE       #   Base address of memory-mapped IO
.option pop

     lw sp,IO_RAM(gp)      # Read RAM size in hw config register and
        #   initialize SP one position past end of RAM
	
     # Should find a way of clearing BSS here...
	
     call main
     tail exit
```
It does different things:
- it loads the IO base address in the global pointer `gp`, so that
  reading and writing to/from memory-mapped peripherals can be done in
  one instruction.
- it initializes the stack pointer `sp` at the end of the RAM. The end
  of the RAM is queried from a memory-mapped hardware configuration 
  register (see `RTL/DEVICES/HardwareConfig.v`).
- it calls `main`
- and finally it calls `exit`

For our bare metal scenario, it is absolutely necessary to replace the
default `crt0.S`, because the default one does not initialize the stack pointer.
If you don't beleive me, if you installed the sources of the riscv toolchain, you can take a 
look at `riscv-newlib/libgloss/riscv/crt0.S`. It is because it is the
job of the OS to do so (and we are writing sort-of an OS, so it is our
job !).

Then, in `FIRMWARE/EXAMPLES/Makefile` I'm generating the executable as follows:
```
%.bm_elf: %.o $(RV_BINARIES)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/CRT_BAREMETAL/femtorv32.ld $< -o $@ \
	-L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC \
	-lfemtorv32 -lfemtoc $(RVGCC_LIB)

```
All the used macros are defined in `FIRMWARE/makefile.inc`. More
explanations below:

- I call it `bm_elf` for bare metal elf, to make the difference with
  standard executables (that will come later).
- Dependency on `$(RV_BINARIES)` is used to automatically download the precompiled toolchain from SiFive;
- `RVLDFLAGS=-m elf32lriscv -b elf32-littleriscv --no-relax` makes sure the right elf format will be used. 
   The `--no-relax` makes sure that the global pointer `gp`, that I'm using for storing the mapped IO page 
   for faster IO, will not be used for something else (that is, making long jumps in one instruction rather 
   than two).
- The `-T` option specifies a linker script
- Important and tricky: note that `ld` automatically links any `crt0.o` file it
   finds in its linker path. Since we have included
   `-LFIRMWARE/CRT_BAREMETAL` in the link path, it will do so !
   (figured out by linking `crt0.o` manually then it complained about
    duplicated symbols !)
- Then I'm linking my FemtoRV32 support library `(-lfemtorv32)` and
   my `femtolibc` with some libc replacement functions (`printf` is a big beast, mine is
   much smaller, though it does not have all the functionalities).
- Finally, `RVGCC_LIB`, also defined in `FIRMWARE/makefile.inc`, that
   points to `libc.a`, `libm.a` and `libgcc.a`
   (`libgcc.a` has integer multiplication / division and floating
   point functions) for the specified
   architecture (`RV32I` or `RV32IM`). This is why it is good to have the
   complete toolchain for embedded systems. Now if you don't have it,
   you can comment-out the definition of `RVGCC_LIB` in
   `FIRMWARE/makefile.inc` and edit `FIRMWARE/LIBFEMTOC/Makefile`, uncomment
   `MISSING_OBJECTS,MISSING_OBJECTS_WITH_DIR`. This will compile
   what's necessary for most included demos (except floating points).
   
OK, so at this point we are able to produce an ELF from a C program,
that will be implanted at address `0x00000000`. Now we need to generate
from it an ASCII hex file that can be understood by Verilog `readmemh()`
function. There is a `objcopy` command that can help:

```
$ riscv64-unknown-elf-objcopy -O verilog firmware.bm_elf firmware.hex    
```
... unfortunately, we are not there yet, because it does not format it
exactly in the way Verilog expects it (or at least I did not find any
way of doing that). There are several ways of fixing that, for instance,
Claire Wolf (picorv32 author) is using a 
[Python script](https://github.com/cliffordwolf/picorv32/blob/master/firmware/makehex.py).
I decided to write a small C++ program called [firmware_words](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/FIRMWARE/TOOLS/FIRMWARE_WORDS_SRC)
that does the job. In addition it checks that everything fits in the
memory declared in `RTL/femtosoc_config.v`. Then, the generated file
`FIRMWARE/firmware.hex` is used to initialize the RAM in
`FIRMWARE/femtosoc.v`, using the `readmemh()` Verilog command.

Then, the script `make_firmware.sh` does all these steps. It is used
as follows:

```
$ cd FIRMWARE
$ ./make_firmware.sh EXAMPLES/xxxx.c
$ cd ..
```
(where `xxxx` is the name of the program you want to compile). It
updates `FIRMWARE/firmware.hex`, then you are ready to program the
FPGA, with `make ULX3S` or `make ICESTICK` or ...


Well, I'm happy, the problem is solved, but since we needed an additional
program, could we not make it read the ELF directly and generate the
Verilog `hex` from it ? (and next, if we know how to read the ELF
format, could we not include that in FemtOS, so that it can directly
select and run programs from the SDCard ?). The answer to both
questions is YES !

Reading ELF executables
-----------------------

Olof Kindgren wrote a Verilog plugin
[here](https://github.com/fusesoc/elf-loader) for FuseSoc, that uses
the standard `libelf`. However, it is a nightmare to compile under
Windows (I don't know if it is even possible). So my idea was different,
can we write the minimal amount of code that fits our needs ?
The ELF (Executable and Linking Format) is complicated, because it
does what it's name tells: it contains what's necessary for loading
programs, that can be dynamically linked. In our case, we are only
using statically linked executables, so we can ignore most of the
information in the ELF file, besides the code sections of course !
Let us take a look at the contents of an ELF file:

```
$readelf -a firmware.bm_elf
```

Wow, lots of things in there. Let us take a look and try to guess:
- first, there is an ELF header, with magic numbers (expected to see
   this), header sizes (can be used to do sanity checks: do we have
   the correct structures declared in the `read_elf` function we are
   writing ?), architecture, 32 or 64 bits, bytesex, OS, and then,
   number of program headers, offset of program headers, number of
   section headers, offsets of section header. So we know we are going
   to open the file, `fread()` the header, then `fseek()` to the offsets
   where there is something that interests us (program headers or
   section headers, no idea of what it is for now), then `fread` them.
- then we see a list of section headers, the names are interesting, 
   `.text`, I see also readonly data `.rodata`, and uninitialized data
   `.bss` and `.sbss`, yes our code is probably there. BTW, what is
   `sbss` ? Google tells me _small data_, it is for data that can be put
   in a page that is faster to access. OK, so we will need to load these
   segments, or zero the `.bss` or `.sbss` ones. Then there are many
   other segments, with debug information, symbol tables, string tables,
   shared string table, we probably do not need that. How can we
   figure out ?
   
Next step: read some code, let us take a look at `/usr/include/elf.h`
on a Linux system. Well, it is very general, it has the definitions for
both 64 bits and 32 bits system, and for any architecture. BTW, we used
the system's `readelf` command instead of the one from the riscv
toolchain and it worked ! The meta-information is completely independent
on the architecture and system, nice. Wow, `elf.h` is a priceless source
of information, all the fields and constants are documented, love it !
There we learn that what we need is `fread`-ing the `Elf32_Ehdr`
structure at the beginning of the file, then `fseek`-ing in the file, at
the `e-shoff` field. Then we read `e_shnum` section headers. Good.
Then, later in `elf.h`, we find the `Elf32_Shdr` structure, with the
explanations for all the columns we could see in the table output by
`readelf`:

| Field      | Description                                                                        |
|------------|------------------------------------------------------------------------------------|
| `sh_type`  | we are interested in `PROGBITS` (load the section) and `NOBITS` (clear the memory) |
| `sh_flags` | `SHF_ALLOC` tells us which section should be really allocated in memory            |
| `sh_addr`  | where the section will be mapped in memory                                         | 
| `sh_offset`| where section data is in the file                                                  |
| `sh_size`  | number of bytes in the section                                                     |

Great ! Now we know exactly what we have to do: for each section of
type `PROGBITS`, if `SHF_ALLOC` is set in the flags, we need to
`fseek` at `sh_offset`, then `fread` `sh_size` bytes that we will
store at `sh_addr`.  For each section of type `NOBITS`, if `SHF_ALLOC`
is set in the flags, we need to clear `sh_size` at `sh_addr`. This is
implemented in `FIRMWARE/LIBFEMTORV32/femto_elf.h/.c`. I have declared
a small structure to keep track of some information. In particular I can
change the base address, because I'm using the same code to load an ELF
to a buffer (then `base_address` points to the buffer), or to load an ELF
in FemtOS (then `base_adress` is `NULL`). I also keep track of the beginning
of the text segment (because to execute the file, FemtOS jumps there), and
the maximum address, to make sure everything fits in memory before loading it:

```
typedef uint32_t elf32_addr; 
typedef struct {
  void*      base_address; /* Base memory address (NULL on normal operation). */
  elf32_addr text_address; /* The address of the text segment.                */
  elf32_addr max_address;  /* The maximum address of a segment.               */
} Elf32Info;
```

Now, in `femto_elf.c`, the function that loads the ELF is as follows (if you look
at the actual file, it has some sanity checks that I removed for legibility):

```
int elf32_parse(const char* filename, Elf32Info* info) {
  Elf32_Ehdr elf_header;
  Elf32_Shdr sec_header;
  FILE* f = fopen(filename,"r");
  uint8_t* base_mem = (uint8_t*)(info->base_address);
  info->text_address = 0;
  
  /* read elf header */
  fread(&elf_header, 1, sizeof(elf_header), f);
  
  /* read all section headers */  
  for(int i=0; i<elf_header.e_shnum; ++i) {
    
    fseek(f,elf_header.e_shoff + i*sizeof(sec_header), SEEK_SET);
    fread(&sec_header, 1, sizeof(sec_header), f);    
    
    /* The sections we are interested in are the ALLOC sections. Skip the other ones. */
    if(!(sec_header.sh_flags & SHF_ALLOC)) continue;

    /* I assume that the first PROGBITS section is the text segment */
    if(sec_header.sh_type == SHT_PROGBITS && info->text_address == 0) {
      info->text_address = sec_header.sh_addr;
    }

    /* Update max address */ 
    info->max_address = MAX(
      info->max_address, 
      sec_header.sh_addr + sec_header.sh_size
    );
     
    /* PROGBIT, INI_ARRAY and FINI_ARRAY need to be loaded. */
    if(
       sec_header.sh_type == SHT_PROGBITS ||
       sec_header.sh_type == SHT_INIT_ARRAY ||
       sec_header.sh_type == SHT_FINI_ARRAY
    ) {
	if(info->base_address != NO_ADDRESS) {
	  fseek(f,sec_header.sh_offset, SEEK_SET);
	  fread(
               base_mem + sec_header.sh_addr, 1,
	       sec_header.sh_size, f
	  );
	}
    }

    /* NOBITS need to be cleared. */    
    if(sec_header.sh_type == SHT_NOBITS && info->base_address != NO_ADDRESS) {	
      memset(base_mem + sec_header.sh_addr, 0, sec_header.sh_size);
    }
  }  
  fclose(f);
  
  return ELF32_OK;
}
```
(if you take a look at `femto_elf.c`, you will see that I've copied
structures definitions and constants from `elf.h`, so that it compiles
everywhere, even in uncivilized Windows countries).

Ok, here we are, so now I am using `femto_elf.h`/`femto_elf.c` in my
`firmware_words` utility that outputs a Verilog ASCII `.hex` file to
initialize the RAM. 

FemtOS and standard ELF executables
-----------------------------------

Now we are equipped with what's necessary to write a very basic and
crappy operating system. I'm doing that on the ULX3S. It is a bare 
metal executable, that displays a list of files on the OLED display, 
lets the user select them with the buttons, and execute the selected file.
Its sources are in `FIRMWARE/EXAMPLES/commander.c`, so you can build
it with:
```
$ cd FIRMWARE
$ ./make_firmware.sh EXAMPLES/commander.c
$ cd ..
```
(then you `$make ULX3S`).

Now you can copy some programs on an SDCard, insert it into the ULX3S,
and run them (`up` and `down` buttons to select, `right` to run). The
`reset` button is the one near the SDCard. 

The executable are produced by:
```
$ cd FIRMWARE/EXAMPLES
$ make xxx.elf
```
(you can also `make everything`, but do not install all of them on the
SDCard, because the interface of FemtOS is very crappy, it does not work
if the list does not fit on the screen, to be fixed). Now if you look at
the rule in `FIRMWARE/EXAMPLES/Makefile`, it is very simple:
```
%.elf: %.o $(RV_BINARIES)
	$(RVGCC) $(RVCFLAGS) $< -o $@ -Wl,-gc-sections \
	-L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc -lm
```
- the macros are defined in `FIRMWARE/makefile.inc` 
- the `-Wl,-gc-sections` flag is just to make sure the linker eliminates the code that is not used (probably not mandatory)

Here we can directly use the default memory map, that places user code
at address '0x10000' (that is, 64Kb). Since FemtOS commander fits in
64Kb, it is perfect for us !

There is something stupid though: a lot of code is duplicated, for
instance if you run `ST_NICCC`, that accesses a file on the SDCard,
all the FAT32 library (by @ultraembedded) is loaded twice: once in
FemtOS, and once in the program image. OK, it is only a few tenths
of Kbs, but I do not like it, it is not good practice. 

There are two different things that we could do:
- implement shared library support
- implement system calls

For the first option, I will need to learn much more about the ELF
format. For the second option, I will need to implement priviledged
instructions and exceptions. This is probably what I'll do next.

_TO BE CONTINUED_
