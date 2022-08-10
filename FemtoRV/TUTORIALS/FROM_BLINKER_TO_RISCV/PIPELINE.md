# From Blinker to RISC-V episode II

In the previous episode, we learnt how to create a fully functional
RISC-V processor on a FPGA. Our processor is not the most efficient,
since it uses between 3 and 4 cycles per instruction. Modern
processors are much more efficient, and can execute several instructions
per cycle, thanks to different techniques. We will see here how to morph
our super-simple processor into a more efficient pipelined processor.

## Step 1: separate instruction and data memory

A pipelined processor always has an instruction cache and a data cache. For now,
I do not know how a cache works, so to make things simpler, the idea is to
design a system with two separate memories.

There is a "program memory":

```verilog
module ProgramMemory (
     input             clk,
     input      [15:0] mem_addr,  
     output reg [31:0] mem_rdata  
);
   reg [31:0] MEM [0:16383]; 
   wire [13:0] word_addr = mem_addr[15:2];
   always @(posedge clk) begin
      mem_rdata <= MEM[word_addr];
   end
   initial begin
      $readmemh("PROGROM.hex",MEM);
   end
endmodule
```

This memory is readonly. It is were the instructions are stored. As can be
seen, it is initialized from a `PROGRAM.hex` file. We will see later how
to create it from an ELF executable.

There is also a "data memory":

```verilog
module DataMemory (
   input             clk,
   input      [15:0] mem_addr,  
   output reg [31:0] mem_rdata, 
   input      [31:0] mem_wdata, 
   input      [3:0]  mem_wmask	
);
   reg [31:0] MEM [0:16383]; 
   wire [13:0] word_addr = mem_addr[15:2];
   always @(posedge clk) begin
      mem_rdata <= MEM[word_addr];
      if(mem_wmask[0]) MEM[word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
      if(mem_wmask[1]) MEM[word_addr][15:8 ] <= mem_wdata[15:8 ];
      if(mem_wmask[2]) MEM[word_addr][23:16] <= mem_wdata[23:16];
      if(mem_wmask[3]) MEM[word_addr][31:24] <= mem_wdata[31:24];	 
   end
   initial begin
      $readmemh("DATARAM.hex",MEM);
   end
endmodule
```

This is where the variables will be stored. `LOAD` and `STORE`
instructions will be able to read and write from/to this memory
(but they won't be agle to access the program memory).

So we will transform our previous processor [step24.v](step24.v) to make it
work with these two memories (of 64 kB each).
First thing to do is changing its interface as follows:

```verilog
module Processor (
    input 	  clk,
    input 	  resetn,
    output [31:0] prog_mem_addr,  
    input [31:0]  prog_mem_rdata, 
    output [31:0] data_mem_addr,  
    input [31:0]  data_mem_rdata, 
    output [31:0] data_mem_wdata, 
    output [3:0]  data_mem_wmask  
);
```

- program memory and data memory are now separated
- there is no longer a `mem_rstrb` signal to read the memory.
  We make it simpler, program memory is read at each cycle, and
  data memory is either read or written at each cycle.
- there is no longer a `mem_rbusy` signal. Memory data is always
  available at the next cycle _so we won't be able to execute from
  SPI flash as before_

The processor needs to be modified to route the `prog_mem_xxx` signals
to instruction fetch, and to route the `data_mem_xxx` signals to the
load/store circuitry. The SOC needs also to be adapted. We keep
address bit 22 for the IO page, and keep the same addresses for the UART,
so that our programs will still work on this processor.

The updated VERILOG source is here: [pipeline1.v](pipeline1.v)

We will also need to write software for our new core. Software takes
the form of two ASCII hexadecimal files, `PROGROM.hex` and
`DATARAM.hex`, with the content of the program memory and the initial
content of the data memory respectively. First thing is to create a new
linker script, with a description of the memory map:

```
MEMORY {
   PROGROM (RX) : ORIGIN = 0x00000, LENGTH = 0x10000  /* 64kB ROM */
   DATARAM (RW) : ORIGIN = 0x10000, LENGTH = 0x10000  /* 64kB RAM */   
}
```
The ROM occupies the 64 first kilobytes, then the RAM.

Then we describe the sections, indicating that text segments should be
sent to `PROGROM`, and the rest should be sent to `DATARAM`:
```
SECTIONS {

    .text : {
        . = ALIGN(4);
	start_dual_memory.o (.text)
        *(.text*)
    } > PROGROM

    .data : {
	. = ALIGN(4);
        *(.data*)          
        *(.sdata*)
        *(.rodata*) 
        *(.srodata*)
        *(.bss*)
        *(.sbss*)
	
        *(COMMON)
        *(.eh_frame)  
        *(.eh_frame_hdr)
        *(.init_array*)         
        *(.gcc_except_table*)  
    } > DATARAM
}
```

The text segment starts with the content of `start_dual_memory.S`:
```asm
.equ IO_BASE, 0x400000  
.section .text
.globl start
start:
        li   gp,IO_BASE
	li   sp,0x20000
	call main
	ebreak
	
```

With this linker script, we can generate an ELF binary with all the code in the
64 first kilobytes of memory, then the data in the next 64 kilobytes. For instance, here is
how to compile Fabrice Bellard's program that computes the decimals of pi:

```
$ cd FIRMWARE
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c pi.c
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   start_dual_memory.S -o start_dual_memory.o 
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   putchar.S -o putchar.o 
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   wait.S -o wait.o 
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c print.c
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c memcpy.c
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c errno.c
$ riscv64-unknown-elf-ld -T dual_memory.ld -m elf32lriscv -nostdlib -norelax pi.o putchar.o wait.o print.o memcpy.o errno.o -lm libgcc.a -o pi.dual_memory.elf
```

The `Makefile` does it for you as follows:
```
$ make pi.dual_memory.elf
```

You can take a look at the memory map:
```
$ readelf -a pi.dual_memory.elf | more
```

then you'll see that `.text` and `.data` are where we expected them to be:
```
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        00000000 000074 003fd8 00  AX  0   0  4
  [ 2] .data             PROGBITS        00010000 004050 0002c0 00  WA  0   0  8
```

To generate `PROGROM.hex` and `DATARAM.hex`, we can use the `firmware_words`
utility that has a `-from_addr` and a `-to_addr` argument to select a portion
of the memory to be written to a `.hex` file:

```
$ firmware_words pi.dual_memory.elf -ram 0x20000 -max_addr 0x20000 -out pi.PROGROM.hex -from_addr 0 -to_addr 0xFFFF
$ firmware_words pi.dual_memory.elf -ram 0x20000 -max_addr 0x20000 -out pi.DATARAM.hex -from_addr 0x10000 -to_addr 0x1FFFF
```

Again, the `Makefile` does it for you (and in addition copies the `.hex` files where they are needed):

```
$ make clean
$ make pi.dual_memory.hex
```
_(you need to `make clean` before else it gets confused by the pre-existing `.elf` file)_

Now you can run `pi` in simulation:

```
$ cd ..
$ ./run_verilator.sh pipeline1.v
```

You can also try other programs (e.g., `tinyraytracer`):
```
$ cd FIRMWARE
$ make tinyraytracer.dual_memory.hex
$ cd ..
$ ./run_verilator.sh pipeline1.v
```

## Step 2: performance counters

The goal of pipelining is to gain some performance, so we need a way
of measuring performance. The RISC-V ISA has a set of special registers
(called CSR for Constrol and Status Registers). There are many CSRs,
used to control interrupts, protection levels, virtual memory... Here
we will only implement two (or four) of them:
- `CYCLE`: counts the clock ticks
- `INSTRET`: counts the number of retired instructions
(with them we can easily compute CPI (clock per instruction) by
dividing `CYCLE` by `INSTRET`).

`CYCLE` and `INSTRET` can be read by the following instructions:
- `RDCYCLE`
- `RDCYCLEH`
- `RDINSTRET`
- `RDINSTRETH`

There are two instructions for each counter because the counters are
64-bit wide. `RDCYCLE` reads the 32 LSBs into `rd` and `RDCYCLEH` reads
the 32 MSBs into `rd` (sae thing for `INSTRET`). 

In fact, these four instructions are pseudo-instructions, all
implemented with a single instruction (`CSRRS`), encoded as follows:


| instr[31:20] | instr[19:15] | instr[14:12] | instr[11:7] | instr[6:0] |
|--------------|--------------|--------------|-------------|------------|
|   CSR Id     |     rs1      |  funct3      |     rd      |   SYSTEM   |
|              |   5'b00000   |  3'b010      |             | 7'b1110011 |


The `CSRRS` instruction atomically reads the
current content of a CSR into `rd` and sets bits of the CSR according
to `rs1`. If `rs1` is `x0`, this just copies the CSR into `rd` (which is
the case for our four pseudo-instructions `RDXXX`).

- the 12 MSBs of the instruction word encode the id of the concerned CSR
- `rs1` will be always `x0` in our case
- `funct3` is `3'b010` for `CSRRS` (there are other instructions for
   manipulating the CSRs that we do not implement here).
- `rd` uses the same bits of the instruction words as usual.
- the opcode is `SYSTEM` (same as `EBREAK` that we use already). We will
  recognize `EBREAK` by `funct3` (that is `3'b000` for `EBREAK`).

The CSR Id is as follows for the four CSR we need to recognize:

| CSR     | Id  | Id (binary)  |
|---------|-----|--------------|
| CYCLE   | C00 | 110000000000 |
| CYCLEH  | C80 | 110010000000 |
| INSTRET | C02 | 110000000010 |
| INSTETH | C82 | 110010000010 |

In our design, we declare two new 64-bit registers. `cycle` is
incremented at each clock tick:

```verilog
   reg [63:0] cycle;   
   reg [63:0] instret;
   
   always @(posedge clk) begin
      cycle <= cycle + 1;
   end
```

and `instret` is incremented each time an instruction is fetched from
program memory:

```verilog
     ...
     WAIT_INSTR: begin
        instr <= prog_mem_rdata[31:2];
        rs1 <= RegisterBank[prog_mem_rdata[19:15]];
        rs2 <= RegisterBank[prog_mem_rdata[24:20]];
        state <= EXECUTE;
        instret <= instret + 1;
     end
     ...
```     

In the instruction decoder, we need to discriminate between
`EBREAK` and `CSRRS`, that both use the `SYSTEM` opcode:

```verilog
   wire isEBREAK     = isSYSTEM & (funct3 == 3'b000);
   wire isCSRRS      = isSYSTEM & (funct3 == 3'b010);
```

Then we declare the value of the read CSR as follows:

```verilog
   wire [31:0] CSR_data =
	       ( instr[27] & instr[21]) ? instret[63:32]:
	       (!instr[27] & instr[21]) ? instret[31:0] :
	             instr[27]          ? cycle[63:32]  :
 	                                  cycle[31:0]   ;
```

(we only examine the bits of `instr` that discriminate between
the four CSRs we have implemented).

Finally, we route it to `writeBackData` when the decoded instruction
is `CSRRS`:

```verilog
   assign writeBackData = (isJAL || isJALR) ? PCplus4   :
			      isLUI         ? Uimm      :
			      isAUIPC       ? PCplusImm :
			      isLoad        ? LOAD_data :
			      isCSRRS       ? CSR_data  :
			                      aluOut;
```

The resuling VERILOG design is available here: [pipeline2.v](pipeline2.v).

Now we need to create some utility functions to easily read the
counters from C programs. It is implemented in
[FIRMWARE/perf.S](FIRMWARE/perf.S). Let us take a look at `rdcycle()`:

```asm
rdcycle:
.L0:  
   rdcycleh a1
   rdcycle a0
   rdcycleh t0
   bne a1,t0,.L0
   ret
```

There are two things to know:
- the RISC-V RV32 ABI returns 64 bit values in `a1` and `a0` (with the 32
  MSBs in `a1`);
- since reading a 64-bit counter uses two instructions, the 32 LSBs
  may wraparound while you read them. To detect this, as explained in
  the RISC-V programmer's manual, one can read the MSBs twice and compare 
  them (and loop until they match).

Note that since it respects the ABI, our function can be called from C
code. We declare it in [perf.h](perf.h) as follows:

```C
#include <stdint.h>
extern uint64_t rdcycle();
```

(same thing for `rdinstret()`).

Let us now test the performance of our processor with a simple
[FIRMWARE/test_rdcycle.c](FIRMWARE/test_rdcycle.c) program:

```C
#include "perf.h"

int main() {
   for(int i=0; i<100; ++i) {
      uint64_t cycles = rdcycle();
      uint64_t instret = rdinstret();      
      printf("i=%d    cycles=%d     instret=%d\n", i, (int)cycles, (int)instret);
   }
   uint64_t cycles = rdcycle();
   uint64_t instret = rdinstret();      
   printf("cycles=%d     instret=%d    100CPI=%d\n", (int)cycles, (int)instret, (int)(100*cycles/instret));
   
}
```

Now we can compile the program, generate the ROM and initial RAM
content, and start simulation as follows:

```
$ cd FIRMWARE
$ make test_rdcycle.dual_memory.hex
$ cd ..
$ ./run_verilator.sh pipeline2.v
```

_Note1:_ in case you wonder, `perf.S` is already included in the list of files to compile
and to link by the `Makefile`.

_Note2:_ our `printf()` function cannot display floating point values, so we display
`100*CPI` instead of `CPI`. 

Then we learn that for this simple loop, our (naive) CPU design runs at around `3.14` CPIs.
Let us see now what it gives with a more realistic program like
`tinyraytracer`. We add instructions to compute CPI and our
"raystones" performance measure here: [FIRMWARE/raystones.c](FIRMWARE/raystones.c).

Let's see what it gives:

```
$ cd FIRMWARE
$ make raystones.dual_memory.hex
$ cd ..
$ ./run_verilator.sh pipeline2.v
```

It will compute and display a simple raytracing scene, and give the
CPI and "raystones" score of the core. 

This program is a C version
of Dmitry Sokolov's [tinyraytracer](https://github.com/ssloy/tinyraytracer).
Raytracing is interesting for benchmarking cores, because it
massively uses floating point operations, either implemented in
software or by an FPU.

Besides CPI (cycles per instruction), the program also computes the
"raystones" score of the PCU.

"raystones" (`pixels/s/MHz` or `pixels/Mticks`) is an 
interesting measure of the core's floating-point performance in
a realistic scenario (raytracing). For our core, we obtain the
following numbers:

| CPI   | RAYSTONES |
|-------|-----------|
| 3.034 | 2.614     |

Our core runs at slightly more than 3 CPIs. Most instructions
take 3 cycles, except loads that take 4 cycles. Raytracing is
quite compute intensive, for a more data intensive program,
the average CPI will be nearer to 4.

The table below gives the raystone performance of several popular
cores:

 | core                 | instr set  | raystones |
 |----------------------|------------|-----------|
 | serv                 | rv32i      |   0.111   |
 |                      |            |           |
 | picorv32-minimal     | rv32i      |   1.45    |
 | picorv32-standard    | rv32im     |   2.352   |
 |                      |            |           |
 | femtorv-quark        | rv32i      |   1.99    |
 | femtorv-electron     | rv32im     |   3.373   |
 | femtorv-gracilis     | rv32imc    |   3.516   |
 | femtorv-petitbateau  | rv32imfc   |  45.159   |
 |                      |            |           |
 | vexriscv imac        | rv32imac   |   7.987   |
 | vexriscv_smp         | rv32imafd  | 124.121   |

The present core is faster than `femtorv-quark`, because
it has a barrel shifter that shifts in 1 cycle. It is slower
than `femtorv-electron` that supports `rv32im` with multiplications
in 1 cycle and divisions in 32 cycles.

What can we expect to gain with pipelining ? Ideally, a pipelined
processor would run at 1 CPI, but this is without stalls required
to resolve certain configurations (rependencies and branches). 
If you compare `femtorv-gracilis` (`rv32imc`) with `vexriscv imac`
(that is pipelined), you can see that `vexriscv` is more than
twice faster.

So our goal is to turn the present processor into a pipelined version,
similar to `vexriscv` but simpler: for now, our ALU, that only supports
the `rv32i` instruction set, operates in a single cycle. Moreover, for
now, we use a separate program memory and data memory, all in BRAM, that
read/writes to memory in 1 cycle. We will see later how to implement
caches.

