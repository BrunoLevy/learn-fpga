Episode I: general understanding on processor design
-------------------------------------------------

To understand processor design, the first thing that I have read was
[this answer](https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog/51621153#51621153)
on Stackoverflow, that I found inspiring.
For a complete course, I highly recommend [this one from the MIT](http://web.mit.edu/6.111/www/f2016/), it also
gives the principles for going much further than what I've done here (pipelines etc...). For
Verilog basics and syntax, I read _Verilog by example by Blaine C. Readler_, it is also short and to the point. 

There are two nice things with the Stackoverflow answer:
- it goes to the essential, and keeps nothing else than what's essential
- the taken example is a RISC processor, that shares several similarities with RISC-V
  (except that it has status flags, that RISC-V does not have).

What we learn there is that there will be a _register file_, that stores
the so-called _general-purpose_ registers. By general-purpose, we mean 
that each time an instruction reads a register, it can be any of them, 
and each time an instruction writes a register, it can be any of them, 
unlike the x86 (CISC) that has _specialized_ registers. To implement the
most general instruction (`register <- register OP register`), the 
register file will read two registers at each cycle, and optionally 
write-back one.

There will be an _ALU_, that will compute an operation on two values.

There will be also a _decoder_, that will generate all required internal signals
from the bit pattern of the current instruction. 

If you want to design a RISC-V processor on your own, I recommend you take a deep look at 
[the Stackoverflow answer](https://stackoverflow.com/questions/51592244/implementation-of-simple-microprocessor-using-verilog/51621153#51621153), 
and do some schematics on your own to have all the general ideas in mind
before going further. 

OK let's see how this
can be translated into something that understands RISC-V instructions.

[Next](FemtoRV32_II.md)