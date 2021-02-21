Episode IV: the ALU and the predicates
-----------------------------------

The ALU is another simple element of the design. In the table Page 130 of
the [RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf),
we
learn that there are 8 possible operations (some of them with two variants, ADD/SUB
and SRL/SRA).
Let us now take a look at the table in page 130 of the
[RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf).
This table is very useful: it indicates how the 32 bits of an instruction are used to encode the parameters of the instruction.
The 7 least significant bits `[6:0]` are used to encode the instruction. Later we will need a component (_instruction decoder_)
with a `switch` statement based on these bits. Now you also see why I'm saying that in fact there are only 11 different
instructions, because there are only 11 different opcodes.
In the table, we see also where the source and destination register indices (`rs1,rs2,rd`) are encoded, as well as
the immediate values (`imm`). We will talk about that later. For now, let us focus on what varies in the register-immediate
ALU instructions (code `0010011`) and the register-register ALU instructions (code `0110011`). Seeing the table,
it will be possible to get the 3-bits `op` from the bits `[14:12]` of the instruction. The 1-bit `opqual` that discriminates
`ADD/SUB` and `SRLI/SRAI` (shift _logical_ immediate / shift _arithmetic_ immediate) correspond to the bit `30` of the
instruction. So we can write the ALU as a combinatorial function. Here is a _simplified_ version of the ALU:

```
module NrvSmallALU (
  input [31:0] 	    in1,
  input [31:0] 	    in2,
  input [2:0] 	    op,     // Operation
  input 	    opqual, // Operation qualification (+/-, Logical/Arithmetic)
  output reg [31:0] out     // ALU result. 
);
   always @(*) begin
      case(op)
        3'b000: out = opqual ? in1 - in2 : in1 + in2;                       // ADD/SUB
        3'b010: out = ($signed(in1) < $signed(in2)) ? 32'b1 : 32'b0 ;       // SLT
        3'b011: out = (in1 < in2) ? 32'b1 : 32'b0;                          // SLTU
	3'b100: out = in1 ^ in2;                                            // XOR
	3'b110: out = in1 | in2;                                            // OR
	3'b111: out = in1 & in2;                                            // AND
        3'b001: out = in1 << in2[4:0];                                      // SLL
        3'b101: out = $signed({opqual ? in1[31] : 1'b0, in1}) >>> in2[4:0]; // SRL/SRA
      endcase 
   end
endmodule
```

The ALU takes as input two 32-bit values `in1` and `in2`, the operation `op`,`opqual` and returns
the result.

_Well, doing so is not very good, because the _barrel shifter_ generated for SLL and SRL/SRA eats up many LUTs,
so it is possible to have an internal register in the ALU, that will shift one position at each clock tick, and
a `busy` signal asserted when the ALU is computed. There is also in FemtoRV32 a trick (suggested by @mecrisp) to
factor the addition/subtraction/comparison in a single adder. But for now, let us just imagine that the ALU is
as above._

Let us get back to the table Page 130 of
the [RISC-V reference manual](https://github.com/riscv/riscv-isa-manual/releases/download/Ratified-IMAFDQC/riscv-spec-20191213.pdf).
There are also 6 branch instructions (code `1100011`) with a varying part in bits `[14:12]` that indicates the test. To implement
these tests, we need another component, that resembles an ALU, but that just compares two values:

```
module NrvPredicate(
   input [31:0] in1,
   input [31:0] in2,
   input [2:0]  op, 
   output reg   out
);
   always @(*) begin
      case(op)
        3'b000: out = (in1 == in2);                   // BEQ
        3'b001: out = (in1 != in2);                   // BNE
        3'b100: out = ($signed(in1) < $signed(in2));  // BLT
        3'b101: out = ($signed(in1) >= $signed(in2)); // BGE
        3'b110: out = (in1 < in2);                    // BLTU
        3'b111: out = (in1 >= in2);                   // BGEU
	default: out = 1'bx; // don't care...
      endcase
   end 
endmodule
```

It takes as input two 32-bit values `in1` and `in2`, the test `op` and outputs a single bit, indicating the
result of the test.

_Same thing here, the comparison can be factored in a single adder as suggested by @mecrisp (see FemtoRV32 source),
but we will ignore that for now._

_Note: I have seen other designs where ALU operations and predicates
       are done by the same unit, and address calculation is done by
       a separate adder. See for instance [this article](http://www.fpgacpu.org/papers/xsoc-series-drafts.pdf
       (not a RISC-V processor but quite similar). I think that my
        design has a smaller footprint, needs to be tested_

[Next](FemtoRV32_V.md)
