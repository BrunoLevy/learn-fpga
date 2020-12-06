FemtoRV32 Design: from zero to I,II,III,IV ... RISC-V
=====================================================

![](Images/FemtoRV32_design.jpg)

_During the first confinement in March 2020, I grabbed an IceStick
just before getting stuck at home, with the idea in mind to learn
verilog and processor design. FemtoRV32 is a super-simple design,
it is too basic (no pipeline), but it may be useful to somebody who
wants to quickly understand the general principles._


Step I: general understanding on processor design
-------------------------------------------------

To understand processor design, the first thing that I have read was
[this answer](https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog/51621153#51621153)
on Stackoverflow. There are too nice things with this answer:
- it does to the essential, and keeps nothing else than what's essential
- the taken example is a RISC processor, that shares several similarities with RISC-V

What we learn there is that there will be a _register file_, that will
read two values from two registers and optionally write-back one.
There will be an _ALU_, that will compute an operation on two values.
There will be also a _decoder_, that will generate all required internal signals
from the bit pattern of the current instruction. OK let's see how this
can be translated into something that understands RISC-V instructions.


Step II: the RV32I instrution set
---------------------------------

Another important source of information is of course the 
[RISC-V reference manual](file:///tmp/mozilla_blevy0/riscv-spec-20191213.pdf).
There you learn that there are several flavors of the RISC-V standard.
Let us start from the simplest one (RV32I, that is, 32 bits base integer 
instruction set). Then we will see how to add things, one thing at a
time. This is a very nice feature of RISC-V, since the instruction set 
is _modular_, you can start with a very small self-contained kernel, and
this kernel will be compliant with the norm. This means standard tools
(compiler, assembler, linker) will be able to generate code for this
kernel. Then I started reading Chapter 2 (page 13 to page 30). Seeing
also the table page 130, there are in fact only 11 different
instrutions ! (I say for instance that an AND, an OR, an ADD ... are
the same instruction, the operation is just an additional parameter).
Now we just try to have an idea of the overall picture,
no need to dive into the details for now. Let's take a look at these
11 instructions:

| instruction | description                |
|-------------|----------------------------|
| branch      | 6 variants                 |
| ALU reg     | 10 variants                |
| ALU imm     | 9 variants (3 shifts)      |
| load        | 5 variants                 |
| store       | 3 variants                 |
| `LUI`       | load upper immediate       |
| `AUIPC`     | add upper immediate to PC  |
| `JAL`       | jump and link              |
| `JALR`      | jump and link register     |
| `FENCE`     | I'll skip this one         |
| `SYSTEM`    | I'll skip this one         |


- The 6 branch variants are conditional jumps, that depend on a test
on two registers. 

- ALU operations can be of the form register op register -> register 
or register op immediate -> register

- Then we have load and store, that can operate
on bytes, on 16 bit values (called half-words) or 32 bit values
(called words). In addition byte and half-word loads can do sign
expansion.

- The remaining instructions are more special (one
may skip their description in a first read, you just need to know
that they are used to implement unconditional jumps, function calls
memory ordering, system calls and breaks):

    - `LUI` (load upper immediate) is used to load the upper 20 bits of a constant. The lower
bits can then be set using `ADDI` or `ORI`. At first sight it may
seem weird that we need two instructions to load a 32 bit constant
in a register, but in fact it is a smart choice, because all
instructions are 32-bit long. 

    - `AUIPC` (add upper immediate to PC) adds a constant to the current program counter and places the 
result in a register. It is meant to be used in combination with 
`JALR` to reach a 32-bit PC-relative address.

    - `JAL` (jump and link) adds an offset to the PC and stores the address
of the instruction following the jump in a register. It can be used to
implement function calls. 'JALR' does the same thing, but adds the
offset to a register. 

    - `FENCE` and `SYSTEMS` are used to implement memory ordering in
multicore systems, and system calls/breaks respectively.

To summarize, we got branches (conditional jumps), ALU operations,
load and store, and a couple of special instructions used to implement
unconditional jumps and function calls. There are also two functions
for memory ordering and system calls (but we will ignore these two
ones for now). OK, in fact only 9 instructions then, it seems doable...
At this point, I do not understand everything, so I'll start from what
I think to be the simplest part.

Step III: the register file
---------------------------

Following the [stackoverflow answer](https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog/51621153#51621153),
at each clock tick, our register file will read two register values
and optionally write one. In addition, we learn from the RISC-V
specification that there is a special register `zero`, that returns always 0 when read, and 
that ignores what is written to it. Clearly we could do tests and
subtract 1 to register IDs, but this would eat-up many LUTS. Reading Claire Wolf's 
[PicoRV32 sources](https://github.com/cliffordwolf/picorv32), we see
there is a smarter way, by negating the register index. There is
another gotcha: we need to read two registers (for instance, the two
operands of an ALU operation). Normally we would need two cycles, but if
we _duplicate_ the entire register file, we can do that in a single
cycle. Here is the Verilog implementation of the register file:

```
module NrvRegisterFile(
  input 	    clk, 
  input [31:0] 	    in,        // Data for write back register
  input [4:0] 	    inRegId,   // Register to write back to
  input 	    inEn,      // Enable register write back
  input [4:0] 	    outRegId1, // Register number for out1
  input [4:0] 	    outRegId2, // Register number for out2
  output reg [31:0] out1,      // Data out 1, available one clock after outRegId1 is set
  output reg [31:0] out2       // Data out 2, available one clock after outRegId2 is set
);
   reg [31:0]  bank1 [30:0];
   reg [31:0]  bank2 [30:0];
   always @(posedge clk) begin
      if (inEn) begin
	 if(inRegId != 0) begin 
	    bank1[~inRegId] <= in;
	    bank2[~inRegId] <= in;
	 end	  
      end 
      out1 <= bank1[~outRegId1];
      out2 <= bank2[~outRegId2];
   end 
endmodule
```

