# From Blinker to Risc-V Episode III - Interrupts

This is WIP, for now just a scratchpad with notes.

Goals:
======

- create a step-by-step gentle introduction, morphing the processor
  obtained at the end of Episode I into something that can run FreeRTOS
  (suggested by @jimmylu890303).

- maybe go a little bit further into the priviledged ISA, and run
  Linux-nommu (only if this does not require too much additional
  material)


I think that @Mecrisp's `individua`  (extended with the memory-mapped register plus the interrupt source) has everything needed. 

- The first thing to do is of course to get the thing running. How to
  add a mapped register is explained
  [here](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV#step-17-memory-mapped-device---lets-do-much-more-than-a-blinky-). Then
  we'll need to wire the interrupt source.

- Then we'll need to write a clear explanation of how the Risc-V
  priviledged instruction set works. This will require some writing,
  because I think that the official specification
  [here](https://riscv.org/wp-content/uploads/2017/05/riscv-privileged-v1.10.pdf)
  is very difficult to read:

  - it lists all possible CSRs, whereas we only need to explain a couple of them
  
  - clarify what are in-processor CSRs and memory-mapped ones (it is
  not super clear to me !)
  
  - explain what happens when an interrupt is fired and what happens
  when one returns from an interrupt
  
- We may also need to explain the RISC-V interrupt controller
  specification
  [PLIC](https://9p.io/sources/contrib/geoff/riscv/riscv-plic.pdf).
  It is unclear to me what is CLINT, what is PLIC etc..., need to
  read more.

For the tutorial, I'd like to continue with the "step by step
incremental modification" approach of episode I, so the "scenario"
could be something like (first draft):

- start from the 'quark' obtained at the end of episode I

- add `interrupt_request` wire, and `mstatus`, `mtvec` CSRs. Wire
  `interrupt_request` to a physical button. Write a simple example
  program that does something interesting. For instance, we could have
  an ascii animation of a bouncing ball, running in an infinite loop,
  and the interrupt adds a random force to the ball. With two buttons,
  we could write something like a 'pong' or 'breakout' game.

- add timer interrupt source. Write an example with minimalistic
  multitasking, demonstrating context swapping (@Mecrisp has it
  already). For instance, we could have two or three balls bouncing on
  the screen, each ball has its own thread.

- now an example with both timer interrupt source and buttons:
  multithreaded pong game, one thread for the ball, one thread for the
  paddle, one thread for game logic

- run FreeRTOS (maybe a couple of intermediary steps needed, in
  particular about simulation / verilator etc...)

List of questions:
==================

- what is the minimal list of CSRs and instructions needed to run  FreeRTOS ? First guess:
  - mepc: saved PC
  - mtvec: interrupt handler
  - mstatus, MIE bit (3) (Interrupt Enable). Do we need other bits ?
  - mcause, interrupt bit (31): do we need other bits ? (e.g., distinguish timer and UART)
  - mtime, mtimecmp
- system calls in FreeRTOS, do they use a trap ? Do we need to distinguish hw interrupt
    from system call ? (additional bit in mcause).
- do we need different protection levels for FreeRTOS ?
- @mecrisp has an `interrupt_request_sticky` flipflop (that transitions to 1 whenever
  the `interrupt_request` goes high, and that transitions to zero after one returns from
  an exception handler). How does it relate with the `MIP` bit (instruction pending) ?
- the specification mentions "memory-mapped CSRs", are they supposed to be both in the
  processor and projected to memory space ? (or any combination of both options ?). I
  think that it is compliant with the norm as soon as the `CSRRx` instruction works
  (either with in-core regs or implemented in a trap handler). So in most
  cases, the minimal in-core kernel has `mepc`, `mtvec`, `mstatus` and `mcause`,
  and triggers an exception as soon as other CSRs are accessed. Then `mtime` and
  `mtimecmp` can be either implemented in another piece of hw (that fires the
  `interrupt_requet` wire) or directly implemented in-core. I wonder what is the
  gain of the first option (external `mtime`, `mtimecmp`), does it make the CPU
  simpler ? I am unsure, because in the end the weight of CPU plus interrupt controller
  will be more or less the same (maybe the address decoder for the CSRs can be simpler,
  we can use 1-hot encoding in the page of memory-mapped CSRs, and let the trap handler
  do the CSR address translation).
- this leads to the questions of what is PLIC,CLINT,CLIC ? (I guess they are
  specifications of how things should work with a separate interrupt logic with
  memory-mapped CSRs, especially in a multicore context where each core can access
  other core's CSRs, but is is still **very unclear** to me). In particular, which
  one is relevant for us ? Do we need to implement one of them or can we do
  something simpler ? I think that PLIC and (A)CLINT are for multi-core systems
  (how a core can access another core's CSR, that are memory-mapped). So I think
  that if one of these is relevant for us, it is probably CLIC. But I also think
  that we probably need none of these, if we implement `mtime` / `mtimecmp` 
  in-core (unless FreeRTOS supposes they are memory-mapped).
  - [PLIC](https://github.com/riscv/riscv-plic-spec/blob/master/riscv-plic.adoc)
  - [(A)CLINT](https://github.com/riscv/riscv-aclint/blob/main/riscv-aclint.adoc)
  - [CLIC](https://github.com/riscv/riscv-fast-interrupt/blob/master/clic.adoc)

Interrupts, Exception, Traps
============================

Definitions
-----------

- Exception: unusual condition of run-time associated with an instruction
- Trap: synchronous transfer to a trap handler caused by exceptional condition
- Interrupt: external event that occurs asynchronously
(if I understand well, a trap is what you return from using Xret. An exception is
 what triggers a trap from the current instruction, and an interrupt is what triggers
 a trap asynchronously, from the timer, or from a special wire).


Interrupts in existing FemtoRV cores
------------------------------------

Matthias has developed three FemtoRVs with interrupt support:
- intermissum (RV32-IM)
- gracilis    (RV32-IMC)
- individua   (RV32-IMAC)

The interrupt logic is common to the three of them. They
have an additional wire `interrupt_request` that triggers an interrupt

They implement the following CSRs:
- `mepc`: saved program counter
- `mtvec`: address of the interrupt handler
- `mstatus` bit x: interrupt enable
- `mcause` bit x: interrupt cause (and lock: already in interrupt handler)
- there is also an `interrupt_request_sticky` flipflop

Besides writing/reading the new CSRs (easy), we need to make three modifications in
our core:
- 1 how the `interrupt_request` discusses with the rest of the chip 
- 2 how (and when) do we jump to a trap handler
- 3 how do we return from a trap handler (that is, what `mret` does)

**1: how `interrupt_request` discusses with `interrupt_sticky`:**

`interrupt_request` only talks to `interrupt_sticky`, and the rest of the chip only sees `interrupt_sticky`.
- if `interrupt_request` goes high, `interrupt_sticky` goes high
- if `interrupt_sticky` is high, it stays high until the interrupt has been processed (that is, until we go through
  the `execute` state that does what should be done with the interrupt).

**2: how (and when) do we jump to a trap handler ?**

we just need to do three things:
- jump to the trap handler, that is, set `PC` to `mtvec`
- save return address, that is, set `mepc` to `PC+4` (or `PC+2` if it is a RV32C instruction)
- indicate that we are in a trap handler, by setting bit 31 of `mcause` (indicates that we are in an interrupt)

It is done in the `EXECUTE` stage under three conditions:
- there is an interrupt pending (`interrupt_request_sticky` is asserted) and
- interrupts are enabled (`MIE`, that is `mstatus`[3] is set) and
- we are not in an interrupt handler already (`mcause`[31]) is not asserted

**3: how do we return from a trap handler ?**
- reset `mcause[31]` to 0
- jump to the return address in `mepc`

It is done in the `EXECUTE` state. `mepc` is selected by the `PC_next` mux when the current instruction is `mret`

**Another view of what happens when an interrupt is triggered**
- 1 `interrupt_request` is asserted by the external interrupt source
- 2 `interrupt_sticky` goes high (and remains high until we are in `EXECUTE`
- 3 `EXECUTE` sets `mcause[31]`, saves the return address to `mepc` and jumps to the trap handler.
     `interrupt_sticky` goes low
- 4 the instructions in the trap handler are executed until current instruction is `mret`
- 5 `EXECUTE` processes `mret` (resets `mcause[31]` and jumps to `mepc`)

Question: in the Risc-V norm, `mstatus` has a `mip` bit (machine interrupt pending). Is it
different or is it the same thing as our `interrupt_sticky` ? 

What I think we need for FreeRTOS
=================================

- We probably need the 'A' instructions (so we can start from FemtoRV-individua)
- We probably need the `ECALL` instruction and the associated bits in `mcause`
- We need `mtime`,`mtimeh` (we can reuse `mcycles`, `mcyclesh`)
- We need `mtimecmp`,`mtimehcmp` and the associated bits in `mcause`
- We probably need an external interrupt source for the UART (we can use the existing `interrupt_request`)
- We may need the `mscratch` CSR
- We probably need `mtval` (machine bad address or instruction)

What I think we need for Linux-noMMU
====================================

Let us take a look at @cnlohr's miniRV32. It has:
- `mstatus`, `mscratch`, `mtvec`, `mie`, `mip`, `mepc`, `mtval`, `mcause` 
- `cycle[l,h]`, `timer[l,h]`, `timermatch[l,h]`  (Q: can't we use cycle as timer ? Q: is timer written ?)
- `extraflags`: privilege (2 bits), WFI (1 bit), Load/Store reservation LSBs (what's that ?)

Remarks, questions:
- It seems we only need the 'm' CSR bank, cool.
- @cnlohr's code is short and easy to read. 
- what is load/store reservation ?
- take a closer look at extraflags
- mini-rv32ima.c contains the "SOC"
- what is the minimum required amount of RAM ?

What is the bare minimal amount of hw to be able to run Linux-noMMU ?
=====================================================================

@MrBossman's [kisc-v](https://github.com/Mr-Bossman/KISC-V) has an interesting super minimalistic implementation,
that emulates the priviledged ISA in trap handlers. It has a trap mechanism that exchanges PC with a pointer stored
at a given address whenever an unknown instruction is encountered.

But there are several things I need to understand:
- how does it make the difference between traps and interrupts ?
   - all regs are copied at fixed address by trap handler
   - trap handler changes the stack pointer to `_sstack` (system stack ?)
   - trap handler calls `entry`
   - trap handler restores regs
   - trap handler jumps to address `back`, that has instruction with opcode `1` (unsupported, so it swaps PC and saved PC)
   - `cause` is deduced from `intc` array at fixed address. Where is `intc` written ? In HDL ? Yes, it seems that it is
     memory-mapped registers in the interrupt controller.
- how does it masks interrupts ?
- how does it handle pending interrupts ?
- what happens if an interrupts occurs when in trap handler ? is it noted as pending ?

Draft for the new tutorial
==========================

The first concept to introduce is sw implementation of new instructions through
trap handler, because we are going to reuse it for memory-mapped CSRs accessed
through SYSTEM instructions.

- 1. Intro, basic notions (traps, interrupts, exceptions)
- 2. Implementing instructions in software
    - the bare minimum: `mtvec`, `mepc`, `mret` (maybe hardwired `mtvec`)
    - software implementation of RV32M
    - software implementation of RV32F (in RV32I and in RV32M: nested traps)
    - mixed software/hardware implementation of RV32F (all variants of FMA and
      comparisons in hardware, and the rest (FDIV,FSQRT...) in software).
- 3. Interrupts
    - now we need `mcause` so that the trap handler can discriminate
    - external interruts source, a `interrupt_request` wire
    - a timer interrupt, basic PLIC implementation, CSRs projected in memory
      space, and access to the CSRs in trap handler
- 4. Run FreeRTOS (maybe in a separate tutorial)
    - The memory environment: FreeRTOS memory mapping, memory-mapped CSRs
    - The instructions to be supported, and CSR access in trap handlers

- 5. Linux (maybe in a separate tutorial)
    - The memory environment: Linux memory mapping, memory-mapped CSRs
    - The instructions to be supported, and CSR access in trap handlers

The smallest (NoMMU)-Linux-capable Core
=======================================

In HW: a non-standard trap-handler mechanism (Mr Bossman's kisc-v) that
works as follows:
- `mtvec` is a hardwired constant address
- There is a memory-mapped `mepc` CSR
- Each time an unrecognized instruction reaches `EXECUTE`, jump to `mepc` and
  replace `mepc` with `PC+4`
- There is also PLIC-like interrupt logic, with memory-mapped
  `mip`, `mie`, `mstatus`, `mcause`

Links:
======
- @cnlohr's [minirv32](https://github.com/cnlohr/mini-rv32ima)

- Stack Overflow questions referenced in minirv32 [here](https://stackoverflow.com/questions/61913210/risc-v-interrupt-handling-flow/61916199#61916199)

- Linux-capable @ultraembedded's simulator [exact-step](https://github.com/ultraembedded/exactstep/blob/master/cpu-rv32/rv32.cpp)

- @regymm [quasi-soc](https://github.com/regymm/quasiSoC)

- @MrBossman [kisc-v](https://github.com/Mr-Bossman/KISC-V)

- @splinedrive [Kian risc-V](https://github.com/splinedrive/kianRiscV)
