Episode V: the instruction decoder
-------------------------------

At this point, we got a register file, that can store and retreive values, we got an ALU that can apply operations
to values, and we got predicates that can test values. The instruction of the processor will be fetched from memory,
let's say the current instruction is stored in a 32-bits register called `instr`.
Each instruction is a 32-bits word. We need now to define the hardware component that will decide what to do with the
registers and with the ALU, based on the instruction. The main reference is again the table in page 130 of the
[RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf).
We know already that there will be a switch statement based on the opcode (bits `[6:0]`):
```
   wire[6:0] opcode = instr[6:0];
```

We also know already that we will need to extract the ALU operation/branch test (bits `[14:12]`):
```
   wire [2:0] op = instr[14:12];
```

There are operations that manipulate registers. They take one (`rs1`) or two (`rs1`,`rs2`) source registers and store the
result in the destination register (`rd`). Still in the same table, we can see that always the same bits of `instr` are
used to encore `rs1` (`[19:15]`), `rs2` (`[24:20]`) and `rd` (`[11:7]`), so we can write some verilog for that:
```
   wire [4:0] rd  = instr[11:7];
   wire [4:0] rs1 = instr[19:15];
   wire [4:0] rs2 = instr[24:20];
```

Another important thing is the little table on the top of page 130.
We learn there that there are several types of instructions. To understand what it means, let's get back to Chapter 2, page 16.
The different instruction types correspond to the way _immediate values_ are encoded in them.

| Instr. type | Description                                    | Immediate value encoding                             |
|-------------|------------------------------------------------|------------------------------------------------------|
| `R-type`    | register-register ALU ops. [more on this here](https://www.youtube.com/watch?v=pVWtI0426mU) | None    |
| `I-type`    | register-immediate integer ALU ops and `JALR`. | 12 bits, sign expansion                              |
| `S-type`    | store                                          | 12 bits, sign expansion                              |
| `B-type`    | branch                                         | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |
| `U-type`    | `LUI`,`AUIPC`                                  | 20 bits, upper `31:12` (bits `[11:0]` are 0)         |
| `J-type`    | `JAL`                                          | 12 bits, sign expansion, upper `[31:1]` (bit 0 is 0) |

Note that `I-type` and `S-type` encode the same type of values (but they are taken from different parts of `instr`).
Same thing for `B-type` and `J-type`.

We will need to reconstruct the immediate values from their bits in the instruction word. To do that, the table in Fig. 2.4,
Page 17 of [RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf)
helps a lot (gives for each immediate format where each bit comes from). It can be directly translated in Verilog as follows:
```
   wire [31:0] Iimm = {{21{instr[31]}}, instr[30:20]};
   wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
   wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
   wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};   
   wire [31:0] Uimm = {instr[31], instr[30:12], {12{1'b0}}};
```
In addition, there will be a mux that selects the right imm format (not shown here).
I will show later how the different signals of the instruction decoder are
generated, in a big `switch` statement.

Sidebar: the elegance of RISC-V
-------------------------------

This paragraph may be skipped, it just contains my own impressions and reflexions on the RISC-V instruction set, inspired by the
comments and Q&A in italics in the
[RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf).

At this point, I realized what an _instruction set architecture_ means: it is for sure a specification of _what bit pattern does what_
(Instruction Set) and it is also at the same time driven by how this will be translated into wires (Architecture). An ISA is not
_abstract_, it is _independent_ on an implementation, but it is strongly designed with implementation in mind ! While the 
pipeline, branch prediction unit, multiple execution units, caches may differ in different implementations, the instruction decoder
is probably very similar in all implementations.

There were things that seemed really weird to me
in the first place: all these immediate format variants, the fact that immediate values are scrambled in different bits of `instr`,
and the weird instructions `LUI`,`AUIPC`,`JAL`,`JALR`. When writing the instruction decoder, you better understand the reasons. The
ISA is really smart, and is the result of a long evolution (there were RISC-I, RISC-II, ... before). It seems to me the result of a 
_distillation_. Now, in 2020, many things were tested in terms of ISA, and this one seems to have benefited from all the previous
attempts, taking the good choices and avoiding the suboptimal ones. 

What is really nice in the ISA is:
- instruction size is fixed. Makes things really easier. _(there are extension with varying instrution length, but at least the core
  instruction set is simple)_;
- `rs1`,`rs2`,`rd` are always encoded by the same bits of `instr`;
- the immediate formats that need to do sign expansion do it from the same bit (`instr[31]`);
- the weird instructions `LUI`,`AUIPC`,`JAL`,`JALR` can be combined to implement higher-level tasks
   (load 32-bit constant in register, jump to arbitrary address, function calls). Their existence is
   justified by the fact it makes the design easier. Then assembly programmer's life is made easier by
   _pseudo-instructions_ `CALL`, `RET`, ... See [risc-v assembly manual](https://github.com/riscv/riscv-asm-manual/blob/master/riscv-asm.md), the
   two tables at the end of the page.

Put differently, to appreciate the elegance of the RISC-V ISA, imagine that your mission is to _invent it_. The constraints are:
- fixed instruction length (32 bits)
- source and destination registers always encoded at the same position
- whenever there is sign-extension, it should be done from the same bit
- it should be simple to load an arbitrary 32-bits immediate value in a register (but may take several instructions)
- it should be simple to jump to arbitrary memory locations (but may take several instructions)
- it should be simple to implement function calls (but may take several instructions)

Then you understand why there are many different immediate
formats. For instance, consider `JAL`, that does not have a source
register, as compared to `JALR` that has one. Both take an immediate
value, but `JAL` has 5 more bits available to store it, since it does
not need to encode the source register. The slightest available bit is
used to extend the dynamic range of the immediates. This explains both
the multiple immediate formats and the fact that they are assembled
from multiple pieces of `instr`, slaloming between the three fixed
5-bits register encodings, that are there or not depending on the
cases.

Now the rationale behind the weird instructions `LUI`,`AUIPC`,`JAL`
and `JALR` is to give a set of functions that can be combined to load
arbitrary 32-bit values in register, or to jump to arbitrary locations
in memory, or to implement the function call protocol as simply as
possible. Considering the constraints, the taken choices (that seemed
weird to me in the first place) perfectly make sense. In addition,
with the taken choices, the instruction decoder is pretty simple and
has a low logical depth. Besides the 7-bits instruction decoder, it
mostly consists of a set of wires drawn from the bits of `instr`, and
duplication of the sign-extended bit 31 to form the immediate values.

OK, now that we see more or less the overall picture, we can now
create the hardware for interpreting the 9 different instructions
(register-register ALU, register-immediate ALU, branch, the 4 weird
instructions, load and store). We will start from a very simple
design, that only supports a linear execution flow, then enrich it
step by step.

[Next](FemtoRV32_VI.md)