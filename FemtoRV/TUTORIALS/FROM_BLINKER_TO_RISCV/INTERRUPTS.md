# From Blinker to Risc-V Episode III - Interrupts

This is WIP, for now just a scratchpad with notes.

Goals:
- create a step-by-step gentle introduction, morphing the processor obtained at the end of Episode I into something that can run FreeRTOS (suggested by @jimmylu890303).
- maybe go a little bit further into the priviledged ISA, and run Linux-nommu (only if this does not require too much additional material)


I think that @Mecrisp's `gracilis`  (extended with the memory-mapped register plus the interrupt source) has everything needed. 

- The first thing to do is of course to get the thing running. How to add a mapped register is explained [here](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV#step-17-memory-mapped-device---lets-do-much-more-than-a-blinky-). Then we'll need to wire the interrupt source. 
- Then we'll need to write a clear explanation of how the Risc-V priviledged instruction set works. This will require some writing, because I think that the official specification [here](https://riscv.org/wp-content/uploads/2017/05/riscv-privileged-v1.10.pdf) is very difficult to read:
  - it lists all possible CSRs, whereas we only need to explain a couple of them
  - clarify what are in-processor CSRs and memory-mapped ones (it is not super clear to me !)
  - explain what happens when an interrupt is fired and what happens when one returns from an interrupt
- We may also need to explain the RISC-V interrupt controller specification [PLIC](https://9p.io/sources/contrib/geoff/riscv/riscv-plic.pdf) . It is unclear to me what is CLINT, what is PLIC etc..., need to read more.

For the tutorial, I'd like to continue with the "step by step incremental modification" approach of episode I, so the "scenario" could be something like (first draft):
- start from the 'quark' obtained at the end of episode I
- add `interrupt_request` wire, and `mstatus`, `mtvec` CSRs. Wire `interrupt_request` to a physical button. Write a simple example program that does something interesting. For instance, we could have an ascii animation of a bouncing ball, running in an infinite loop, and the interrupt adds a random force to the ball. With two buttons, we could write something like a 'pong' or 'breakout' game.
- add timer interrupt source. Write an example with minimalistic multitasking, demonstrating context swapping (@Mecrisp has it already). For instance, we could have two or three balls bouncing on the screen, each ball has its own thread.
- now an example with both timer interrupt source and buttons: multithreaded pong game, one thread for the ball, one thread for the paddle, one thread for game logic
- run FreeRTOS (maybe a couple of intermediary steps needed, in particular about simulation / verilator etc...)
