Episode VI: Linear execution flow, `reg <- reg OP reg` ALU instructions
--------------------------------------------------------------------
![](Images/FemtoRV32_design_1.jpg)

Let us start with a very simple processor, that can only execute a
linear stream of `reg <- reg OP reg` instructions stored in an RAM. On
the left part of the design, the `NextPC` is always obtained by adding
4 to the `PC`. In the middle part, the instruction is fetched from the
RAM and stored in `Instr`. The two sources and the destination
register are extracted by the decoder, and sent to the register
file. The two values read from the register file are fed to the ALU,
that computes the operation also extracted by the decoder. Finally
this value is written back to the register file.

The finite state machine that controls it is very simple, with three
states. At the beginning of `Instr Fetch`, the program counter `PC`
contains a valid address. The instruction is ready in `Instr` at the
beginning of the next state, `Register Fetch`. The two source and
destination registers are also ready, since they are just 5-bits words
extracted from `Instr` at fixed position. At the beginning of `Write
Back`, the two source registers and the computed value are ready
(because we have a purely combinatorial ALU, with a more complicated
one we would need to wait for it to be ready). Then the result is
written to the register file, and `PC` is replaced with `NextPC`.

(TODO: add testbench and example designs)

[Next](FemtoRV32_VII.md)