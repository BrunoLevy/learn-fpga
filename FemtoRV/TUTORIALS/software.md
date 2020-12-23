Software and compilers
======================

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

RISC-V executables
------------------

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


