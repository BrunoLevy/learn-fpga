# From Blinker to Risc-V Episode III - Interrupts

This is WIP, for now just a scratchpad with notes.

Goals:

- create a step-by-step gentle introduction, morphing the processor
  obtained at the end of Episode I into something that can run FreeRTOS
  (suggested by @jimmylu890303).

- maybe go a little bit further into the priviledged ISA, and run
  Linux-nommu (only if this does not require too much additional
  material)


I think that @Mecrisp's `gracilis`  (extended with the memory-mapped register plus the interrupt source) has everything needed. 

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

Links:

- @cnlohr's [minirv32](https://github.com/cnlohr/mini-rv32ima)

- Linux-capable @ultraembedded's [exact-step](https://github.com/ultraembedded/exactstep/blob/master/cpu-rv32/rv32.cpp)

- @regymm [quasi-soc](https://github.com/regymm/quasiSoC)
