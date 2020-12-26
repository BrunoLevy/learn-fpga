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
|msr        | machine status register
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

Now I take a look again at _volume II_. Most of what we want to learn is in the description of 
`msr`, the machine status register. In step 1, we have a simple configuration, with only machine mode.
We make it even simpler, with no interruptions, and only exceptions. Then we only need the following
CSRs:

| name      | description                                             |
|-----------|---------------------------------------------------------|
|mepc       | machine exception program counter                 
|mcause     | machine trap cause              
|msr        | machine status register
|mtvec      | machine trap handler base address (also called mevec)
|mtval      | machine bad address or instruction
(in addition there is a `mscratch` scratch register that can be used by the exception handlers).

Let us take a look now at the code that handles exceptions, line 755. Since we only have machine mode,
we directly jump to line 800:
```
        uint32_t s = m_csr_msr;

        // Interrupt save and disable
        s &= ~SR_MPIE;
        s |= (s & SR_MIE) ? SR_MPIE : 0;
        s &= ~SR_MIE;

        // Record previous priviledge level
        s &= ~SR_MPP;
        s |= (m_csr_mpriv << SR_MPP_SHIFT);

        // Raise priviledge to machine level
        m_csr_mpriv  = PRIV_MACHINE;

        m_csr_msr    = s;
        m_csr_mepc   = pc;
        m_csr_mcause = cause;
        m_csr_mtval  = badaddr;

        log_exception(pc, m_csr_mevec, cause);

        // Set new PC
        m_pc = m_csr_mevec;
```
In a nutshell, calling the exception means _doing something with the machine status register_ (we'll see later),
then setting `mepc` (to the current or the next instruction ? we'll see later), `mcause` and `mtval`, then jumping
to `mevec` (and also changing privilege level, but at step 1 we do not do that).


and we take a look at the way `MRET` is handled, line 1363:

```
        DPRINTF(LOG_INST,("%08x: mret\n", pc));
        INST_STAT(ENUM_INST_MRET);

        assert(m_csr_mpriv == PRIV_MACHINE);

        uint32_t s        = m_csr_msr;
        uint32_t prev_prv = SR_GET_MPP(m_csr_msr);

        // Interrupt enable pop
        s &= ~SR_MIE;
        s |= (s & SR_MPIE) ? SR_MIE : 0;
        s |= SR_MPIE;

        // Set next MPP to user mode
        s &= ~SR_MPP;
        s |=  SR_MPP_U;

        // Set privilege level to previous MPP
        m_csr_mpriv   = prev_prv;
        m_csr_msr     = s;

        // Return to EPC
        pc = m_csr_mepc;
    }
```
OK, more or less what I expected, that is _undoing the stuff with the machine status register_, and jumping to the
previously stored address in `mepc` (and also changing privilege level but we do not need to do that in step 1).

Two questions remain to be answered:
- is `mepc` set to the instruction that caused the exception or to the next instruction ? Seeing what `MRET` does, it seems
  to be the next instruction, but we need to make sure: imagine we use compressed mode instructions implanted in an exception
  handler, then we would need to determine whether the instruction that caused the exception was `mepc-4` or `mepc-2`, painful !
  (but I think it is the case)
- what is the stuff to be done and undone with the machine status register ? There are some bit manipulations with `SR_MIE` and `SR_MPIE`
  (probably for _machine interrupt enable_ and _machine pending interrupt enable_ or something). For now we can ignore them, since we mainly
  want to implement `ECALL`. We will see interrupts after. Then there is something with `MPP`, what's that ? It is defined in `rv32_isa.h` but
  there is no comment (the author supposes you are familiar with it already, which is not my case !), so let's dig in _volume II_: it is page 20,
  on `mstatus`: it is a stack used to keep track of the privilege level (and again, in our step 1 we can ignore this).


Two things: 
1) "interrupt enable stack" (depth 3, in fact 2), stored in machine status register.
   MIE : Machine Interrupt Enable
   MPIE: Machine Previous Interrupt Enable
2) MPP (Machine Privilege P?) ?   


References
----------
- [The RISC-V manual, volume II (priviledged architecture)](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMFDQC-and-Priv-v1.11/riscv-privileged-20190608.pdf)
- @ultraembedded's [exactstep](https://github.com/ultraembedded/exactstep)
