Priviledged instruction set
===========================

Now I'd like to extend FemtoRV32 to make it Linux-capable, step by
step. Here is the plan:

- The first step is to implement exceptions, interrupts, the `ECALL`
instruction, and catch system calls in an exception handler. This is
still with a single privilege level (machine mode). At the end of the
first step, it will be possible to run ELF executables compiled with
gcc and its standard library.

- The second step is to implement two privilege levels, and protect the
memory used in machine mode.

- The third step is to implement the MMU and virtual adressing.

Let's see how to implement the privileged instruction set.
Unfortunately, the 
[Volume II of the RISC-V manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMFDQC-and-Priv-v1.11/riscv-privileged-20190608.pdf)
(privileged instruction set) is - I think - not written as well as
volume I. With volume I on my knees, I could write the Verilog for
RV32I in a couple of days. With Volume II, it is another story, because
Volume II lists all the CSR registers, without giving a structured view
of what does what, and of what's important and what's optional. 

There is another source of information that we can use: @ultraembedded
developed a software emulator for different processors, including RV32
(and RV64), it is [here](https://github.com/ultraembedded/exactstep).
Interestingly, it is driven cycle by cycle, so it is a good starting
point for having a more _systemic_ view of the privileged instruction
set. So I'll continue, with _RISC-V Volume II_ on my knees and two
open tabs with [rv32.h](https://github.com/ultraembedded/exactstep/blob/master/cpu-rv32/rv32.h)
and [rv32.cpp](https://github.com/ultraembedded/exactstep/blob/master/cpu-rv32/rv32.cpp).

The first thing I'll do is noting in `rv32.h` which CSR are used, and
looking them up in _RISC-V Volume II_. Here is the list:

CSR registers
-------------

| name      | description                                             |
|-----------|---------------------------------------------------------|
|mepc       | machine exception program counter                 
|mcause     | machine trap cause              
|msr        | ??
|mpriv      | current privilege level (non-standard)
|mtvec      | machine trap handler base address (also called mevec)
|mtval      | machine bad address or instruction
|mie        | machine interrupt enable
|mip        | machine interrupt pending
|mtime      | machine timer register
|mtimecmp   | machine timer register
|mtime_ie   | (bool)  time interrupt enable ?
|mscratch   | scratch register for machine trap handlers
|mideleg    | machine interrupt delegation register
|medeleg    | machine exception delegation register
|           |
|sepc       | supervisor exception program counter
|stvec      | supervisor trap handler base address (also called sevec)
|scause     | supervisor trap cause
|stval      | supervisor bad address or instruction
|satp       | supervisor address translation and protection
|sscratch   | scratch register for supervisor trap handlers

So we got machine mode CSRs and supervisor mode CSRs. I'm wondering
how these are used when the processor is running Linux (which
@ultraembedded's emulator can do). I do not see
user mode CSRs here, but maybe they are not used: in _Volume II_ I see
that user-mode CSRs comprise trap status and handling, and maybe Linux 
does not have user-mode traps. There are also CSRs for the FPU (that 
I'll consider later-on) and counter/timers (some of them I already have
implemented). For now, we will only consider the machine mode CSRs that
we need for step 1.

Let us know take a look at _rv32.cpp_. The file is not that long (2308
lines), there are somme comments, the code seems to be very well
written. It seems we found a good source. Let us browse the source
file and write its table of contents:

- _line 1 to 173_:   low level get/set for CSRs, `reset()`, instruction fetch
- _line 174 to 433_: MMU (we will see that later, not needed for step 1. We keep in mind it's there)
- _line 437 to 555_: load and store (with interface to the MMU)
- _line 558 to 751_: high level get/set for CSRs, with exception triggering
- _line 755 to 827_: the function that handles exceptions and interrupts, *we need to understand*
- _line 831 to 2188_: a huge function that implements the `execute` step
    -  _line 1344 to 1411_: `ECALL`, `EBREAK`, `MRET`, `SRET`, *we need to understand*
    -  _line 2155 to 2185_: take exceptions and interrupts, *we need to understand*
- _line 2192 to 2229_: the function that simulates one clock cycle
- _line 2233 to 2281_: interrupt set/clear, *we need to understand*
- _line 2282 to 2308_: statistics

_TO BE CONTINUED_

References
----------
- [The RISC-V manual, volume II (priviledged architecture)](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMFDQC-and-Priv-v1.11/riscv-privileged-20190608.pdf)
- @ultraembedded's [exactstep](https://github.com/ultraembedded/exactstep)
