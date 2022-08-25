# From Blinker to RISC-V episode II

In the [previous episode](README.md), we learnt how to create a fully functional
RISC-V processor on a FPGA. Our processor is not the most efficient,
since it uses between 3 and 4 cycles per instruction. Modern
processors are much more efficient, and can execute several instructions
per cycle, thanks to different techniques. We will see here how to morph
our super-simple processor into a more efficient pipelined processor.

For this episode, you will need a FPGA with at least 128kB BRAM
(e.g., ULX3S). You can also run it purely in simulation. 

## Step 1: separate instruction and data memory

Our previous processor [step24.v](step24.v) has a "unified memory",
and accesses both program and
data using the same wires. For a pipelined processor, things are different
internally: it has a separate program memory and data memory. In fact, these
memories are caches, filled from a unique memory bus connected to the outside
world. For now, I don't know how a cache works (will be for next steps), so
to make things simpler, we will have a "program ROM" and a "data RAM" in the
processor (64 kB each), directly initialized from a `.hex` file (we will see
later how to create these `.hex` files from an `ELF` executable):

```verilog
   reg [31:0] PROGROM [0:16383];
   reg [31:0] DATARAM [0:16383];   
   initial begin
      $readmemh("PROGROM.hex",PROGROM);
      $readmemh("DATARAM.hex",DATARAM);      
   end
```

- `PROGROM` is where instructions are stored;
- `DATARAM` is where the variables are stored. `LOAD` and `STORE`
instructions will be able to read and write from/to this memory
(but they won't be able to access the program memory).


The previous memory busses are replaced with internal wires:

```verilog
   wire [31:0] mem_addr;
   wire [31:0] mem_rdata;
   wire [31:0] mem_wdata;
   wire [3:0]  mem_wmask;
```

As compared to before, `mem_rstrobe` and `mem_rbusy` are no longer here:
the internal memories always delivers the data at `mem_addr` at the next
cycle. 

To be able to talk to the outside world, our processor still has a 
memory bus for the mapped IO page (that we use to communicate with
the `UART` and other devices):

```verilog
module Processor (
    ...
    output [31:0] IO_mem_addr,  
    input [31:0]  IO_mem_rdata, 
    output [31:0] IO_mem_wdata, 
    output 	  IO_mem_wr     
);
```

Now we need to route everything to the internal memory busses. We keep the
same IO page as before (so that we can reuse the same code), indicared by
bit 22 of memory addresses:

```verilog
   wire isIO  = mem_addr[22];
   wire isRAM = !isIO;
```

Data ram is read and optionally written at each cycle, as follows:

```verilog
   wire [13:0] mem_word_addr = mem_addr[15:2];
   reg [31:0] dataram_rdata;
   wire [3:0] dataram_wmask = mem_wmask & {4{isRAM}};
   always @(posedge clk) begin
      dataram_rdata <= DATARAM[mem_word_addr];
      if(dataram_wmask[0]) DATARAM[mem_word_addr][ 7:0 ] <= mem_wdata[ 7:0 ];
      if(dataram_wmask[1]) DATARAM[mem_word_addr][15:8 ] <= mem_wdata[15:8 ];
      if(dataram_wmask[2]) DATARAM[mem_word_addr][23:16] <= mem_wdata[23:16];
      if(dataram_wmask[3]) DATARAM[mem_word_addr][31:24] <= mem_wdata[31:24];
   end
```

Then we can plug the external IO busses:

```verilog
   assign mem_rdata = isRAM ? dataram_rdata : IO_mem_rdata;
   assign IO_mem_addr  = mem_addr;
   assign IO_mem_wdata = mem_wdata;
   assign IO_mem_wr    = isIO & mem_wmask[0];
```

Finally, there is a couple of simple modifications to make:
- Instruction is fetched from `PROGROM` during `FETCH_INSTR` state: `instr <= PROGROM[PC[15:2]];`
- The `mem_rbusy` signal is no longer there (remember, `DATARAM` and `PROGROM` are systematically
  accessed in one cycle), so the state machine is simplified. The price to pay is that we
  will not be able to execute programs from SPI flash as before (when `PROGROM` will be replaced
  with an _instruction cache_ it will be possible again).

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
	start_pipeline.o (.text)
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

The text segment starts with the content of `start_pipeline.S`:
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
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   start_pipeline.S -o start_pipeline.o 
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   putchar.S -o putchar.o 
$ riscv64-unknown-elf-as -march=rv32i -mabi=ilp32   wait.S -o wait.o 
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c print.c
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c memcpy.c
$ riscv64-unknown-elf-gcc -Os -fno-pic -march=rv32i -mabi=ilp32 -fno-stack-protector -w -Wl,--no-relax   -c errno.c
$ riscv64-unknown-elf-ld -T pipeline.ld -m elf32lriscv -nostdlib -norelax pi.o putchar.o wait.o print.o memcpy.o errno.o -lm libgcc.a -o pi.pipeline.elf
```

The `Makefile` does it for you as follows:
```
$ make pi.pipeline.elf
```

You can take a look at the memory map:
```
$ readelf -a pi.pipeline.elf | more
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
$ firmware_words pi.pipeline.elf -ram 0x20000 -max_addr 0x20000 -out pi.PROGROM.hex -from_addr 0 -to_addr 0xFFFF
$ firmware_words pi.pipeline.elf -ram 0x20000 -max_addr 0x20000 -out pi.DATARAM.hex -from_addr 0x10000 -to_addr 0x1FFFF
```

Again, the `Makefile` does it for you (and in addition copies the `.hex` files where they are needed):

```
$ make clean
$ make pi.pipeline.hex
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
$ make tinyraytracer.pipeline.hex
$ cd ..
$ ./run_verilator.sh pipeline1.v
```

If you have a ULX3S, plug it to a USB port, then:
```
$ BOARDS/run_ulx3s.sh pipeline1.v
$ ./terminal.sh
```

## Step 2: performance counters

The goal of pipelining is to gain some performance, so we need a way
of measuring performance. The RISC-V ISA has a set of special registers
(called "CSR" for Constrol and Status Registers). There are many CSRs,
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
        rs1 <= RegisterBank[instr[19:15]];
        rs2 <= RegisterBank[instr[24:20]];
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
$ make test_rdcycle.pipeline.hex
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
$ make raystones.pipeline.hex
$ cd ..
$ ./run_verilator.sh pipeline2.v
```

It will compute and display a simple raytracing scene, and give the
CPI and "raystones" score of the core. 

You can also run it on device (ULX3S):
```
$ BOARDS/run_ulx3s.sh pipeline1.v
$ ./terminal.sh
```

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
to resolve certain configurations (dependencies and branches), more
on this later. 
If you compare `femtorv-gracilis` (`rv32imc`) with `vexriscv imac`
(that is pipelined), you can see that `vexriscv` is more than
twice faster.

So our goal is to turn the present processor into a pipelined version,
similar to `vexriscv` but simpler: for now, our ALU, that only supports
the `rv32i` instruction set, operates in a single cycle. Moreover, for
now, we use a separate program memory and data memory, all in BRAM, that
read/writes to memory in 1 cycle. We will see later how to implement
caches.

## Step 3: a sequential 5-stages pipeline

A pipelined processor is like a multi-cycle processor that uses a state machine,
but each state has its own circuitry, and runs concurrently with the other states,
and passes its outputs to the next state (one talks about stages rather than states).
Since there are several tricky situations to handle, and since I don't know for now
exactly how to do that, my idea is to go step by step, and first write a core that
has all the stages, but drive it with a state machine that executes one stage at a time
instead of running them concurrently. Then we will see what needs to be modified when
all the stages run concurrently.

Following all good books in processor design (Patterson, Harris...) we will start
with a super classical design with 5 stages:

| acronym | long name            | description                           |
|---------|----------------------|---------------------------------------|
| IF      | Instruction fetch    | reads instruction from program memory |
| ID      | Instruction decode   | decodes instruction and immediates    |
| EX      | Execute              | computes ALU, tests and addresses     |
| MEM     | read or write memory | load and store                        |
| WB      | Write back           | writes result to register file        |

Each stage will read its input from a set of registers and write its outputs
to a set of registers.In particular, each stage will have its own copy of the
program counter, the current instruction, and some other fields derived from
them (well, in fact we will be able to drop the program counter and the
instruction word in the last stages, but for now we suppose we keep everyting).

In short, to be more precise, each stage needs to have its own copy of everything it needs to
operate properly. Why is this so ?

- Remember that even if for now we launch them sequentially, all stages are supposed to run
  concurrently (it will be so in our next step). In particular, it means that each stage
  will process a *different* instruction (and a *different* associated PC);
- besides the advantage of increasing throughput, there is another reason: by separating
  execution into multiple register-to-register stages, pipelining often results in a
  shorter critical path (hence supports a higher frequency).

OK, so for this first step, we are going to create a multi-cycle CPU, and each state
will correspond to the table above. So there will be a state machine that goes through
all the states systematically, as follows:

```verilog
   localparam F_bit = 0; localparam F_state = 1 << F_bit;
   localparam D_bit = 1; localparam D_state = 1 << D_bit;
   localparam E_bit = 2; localparam E_state = 1 << E_bit;
   localparam M_bit = 3; localparam M_state = 1 << M_bit;
   localparam W_bit = 4; localparam W_state = 1 << W_bit;
   reg [4:0] 	  state;
   wire           halt;
   always @(posedge clk) begin
      if(!resetn) begin
	 state  <= F_state;
      end else if(!halt) begin
	 state <= {state[3:0],state[4]};
      end
   end
```

We will remove this state machine in the next step, but for now it is better to run the stages
sequentially, so that we do not have to worry about some nasty things. We will have no choice
later, but it is easer, at least for me, to introduce one difficulty at a time, and test at
each step that the CPU still works, by running the `RAYSTONES` benchmark.

We can now review **the rules of the game** that we are going to play:
- Consider stage names `A`,`B`,`C`,`D`,`E` (easier to remember than
  `F`,`D`,`E`,`M`,`W` even if we will soon use these names instead).
   Each stage reads its input from a set of registers and writes its output to a
  set of registers. The output of a stage (for instance `B`) corresponds to the input of the
  next stage (for instance `C`). To make things easier, the names of these registers
  (that are both the output of `B` and the input of `C`) are prefixed by `BC_`. Still
  considering `B`, it reads its input from registers prefixed by `AB_` and writes its
  output to registers prefixed by `BC_`. Then, `C` reads its input from registers
  prefixed by `BC_` and writes its output to registers prefixed by `CD_`, and so on
  and so forth... Hence, the Verilog code for the `B` stage looks like:

```verilog
   always @(posedge clk) begin
     if(state[B_bit]) begin
         BC_xxx <= AB_aaa;
	 BC_yyy <= AB_bbb;
	 ...
     end
   end
```

- But that's not all, each stage can have some combinatorial logic. For instance, in the `E` stage,
the ALU reads its input from two registers `DE_rs1` and `DE_rs2` and outputs its result in `EM_Eresult`.
This combinatorial function can be written with intermediary signals, that are always wires, and that
are prefixed by the name of the state. In stage `B`, these signals take as input either registers
prefixed by `AB_` or other signals prefixed by `B_`.

- And some states will read and/or write memories (the program ROM, the data RAM and the register file).
In stage `B`, for writing to a memory, the address and the data to be written can be either an `AB_`-prefixed
register or a `B_` prefixed wire. For reading from a memory, the output should always be a `BC_`-prefixed
register and nothing else than reading the data should be done _(this is because each memory already has
a registered reading port, and complying to this rule lets the synthesizer map the `BC_` target to this
registered reading port)_.

Let us summarize the rules:

- **Rule 1** State `B` takes its inputs from `AB_`-prefixed registers and writes its output to `BC_`-prefixed
   registers;

- **Rule 2** State `B` can have intermediary wires. Their names are prefixed by `B_`. Their inputs are either
  `AB_`-prefixed registers or `B_`-prefixed wires;

- **Rule 3** If state `B` reads a memory, the result is always stored into a `BC_`-prefixed register and nothing
   else is done to the result;

Or put differently: in state `B`, on the left of `<=` there can be only a `BC_`-prefixed
register. On the right of `<=` or `=` there can be only a `BC_`-prefixed register, a `B_`-prefixed
wire or some combinations of these...

However, there are two **exceptions to the rules** (else it would be too simple !):

- When there is a jump or a taken branch, the program counter, managed by the `F`etch state, needs to be
  modified. So there is a 32-bits signal `jumpOrBranchAddress` and a 1-bit signal `jumpOrBranch` that is
  asserted whenever the program counter needs to be updated to `jumpOrBranchAddress`;

- most instructions write back their result to the register file. Hence there is a 32-bits signal `wbData`
  with the value to be written, a 5-bits signal `wbRdId` that indicates in which register the value should
  be written, and a 1-bit signal `wbEnable` that is asserted each time `wbData` should be written to
  register `wbRdId`.

If you imagine that an instruction travels from the left to the right through all the states
(`F`etch, `D`ecode, `E`xecute, `M`emory, `W`riteback), you can see that these two sets of signals
travel from the right to the left (so in a certain sense, they go "back in time").
This is what causes all the difficulties we will have in the next step
(but we do not have any difficulty for now since we activate one stage at a time, sequentially).

One more thing: I'm pretty sure that I'm not going to get this right directly, so debugging is
important. For that, I've written in VERILOG a simple [RISC-V disassembler](riscv_disassembly.v).
It can be used in simulation to display the instructions in all the stages of the pipeline, it
is super-useful to track bugs.

OK, so to make things simple, and to be able to use the disassembler, we will store the PC and
the current instruction in all stage (and of course, it will be a different instruction in all
stage).

### Fetch

Let us see what the `F`etch stage looks like:

```verilog
   reg  [31:0] F_PC;
   reg  [31:0] PROGROM[0:16383]; 

   initial begin
      $readmemh("PROGROM.hex",PROGROM);
   end

   always @(posedge clk) begin
      if(!resetn) begin
	 F_PC    <= 0;
      end else if(state[F_bit]) begin
	 FD_instr <= PROGROM[F_PC[15:2]];
	 FD_PC    <= F_PC;
	 F_PC     <= F_PC+4;
      end else if(jumpOrBranch) begin
	 F_PC  <= jumpOrBranchAddress;	 
      end      
   end
   
/******************************************************************************/
   reg [31:0] FD_PC;   
   reg [31:0] FD_instr;
/******************************************************************************/

```

The `F` stage is a bit particular, in the sense that it is the first stage. It
does not have any input, but it has the program counter `F_PC` and the instruction
ROM. It outputs the PC and the loaded instruction to the `Ð`ecode stage. Note that
it handles the "exceptions to the rule" signals (`jumpOrBranch` and `jumpOrBranchAddress`)
that come from later stages.

### Decode

The `Ð`ecode stage is responsible for recognizing the opcodes, 
extracting the immediates from the instruction, and fetching the operands
from the register file. To make things as simple as possible, for now, we
are going to decode the instruction each time we need it instead of
doing that in the decode stage. It sounds a bit crazy, but for now the goal
is to understand how a pipelined design works. Then we will see later how
to optimize the design. Another reason is that we want to be able to
display the instructions in each stage with our disassembler, hence it
requires each stage to have the instruction and PC, and I'd rather keep
the information in a single form in the system (else it is a potential
source of bugs). Hence our Decode stage is implemented as follows:

```verilog
   reg [31:0] RegisterBank [0:31];
   
   always @(posedge clk) begin
      if(state[D_bit]) begin
	 DE_PC    <= FD_PC;
	 DE_instr <= FD_instr;
	 DE_rs1 <= RegisterBank[rs1Id(FD_instr)];
	 DE_rs2 <= RegisterBank[rs2Id(FD_instr)];
      end
   end

   always @(posedge clk) begin
      if(wbEnable) begin
	 RegisterBank[wbRdId] <= wbData;
      end
   end
   
/******************************************************************************/
   reg [31:0] DE_PC;
   reg [31:0] DE_instr;
   reg [31:0] DE_rs1;
   reg [31:0] DE_rs2;
/******************************************************************************/
```

It passes the PC and the instruction to the next stage (Execute) through `DE_PC`
and `DE_instr`, and it fetches the two operands from the register file into
`DE_rs1` and `DE_rs2`. To make the source more readable, there are some helper
functions to extract the different fields and immediates from an instruction:

```verilog
   function isALUreg; input [31:0] I; isALUreg=(I[6:0]==7'b0110011); endfunction
   function isALUimm; input [31:0] I; isALUimm=(I[6:0]==7'b0010011); endfunction
   function isBranch; input [31:0] I; isBranch=(I[6:0]==7'b1100011); endfunction
   ...
   function [4:0] rs1Id; input [31:0] I; rs1Id = I[19:15];      endfunction
   function [4:0] rs2Id; input [31:0] I; rs2Id = I[24:20];      endfunction
   function [4:0] rdId;  input [31:0] I; rdId  = I[11:7];       endfunction
   ...
   function [2:0] funct3; input [31:0] I; funct3 = I[14:12]; endfunction
   function [6:0] funct7; input [31:0] I; funct7 = I[31:25]; endfunction
   ...
   function [31:0] Uimm; input [31:0] I; Uimm={I[31:12],{12{1'b0}}}; endfunction
   ...
```

(they are also used in the subsequent stages).

Note also the "exception to the rule" signals `wbEnable`, `wbRdId` and `wbData` and
the way they are used to write back into the register file.

### Execute

The `E`xecute stage works exactly like in Episode I, it has a big combinatorial
function `E_aluOut` (with the 32-bits result of the current operation)
and `E_takeBranch` (the 1-bit result of the tests for branches), not reproduced
here. Then one can derive the following signals:

```verilog
   wire E_JumpOrBranch = (
         isJAL(DE_instr)  || 
         isJALR(DE_instr) || 
         (isBranch(DE_instr) && E_takeBranch)
   );

   wire [31:0] E_JumpOrBranchAddr =
	isBranch(DE_instr) ? DE_PC + Bimm(DE_instr) :
	isJAL(DE_instr)    ? DE_PC + Jimm(DE_instr) :
	/* JALR */           {E_aluPlus[31:1],1'b0} ;

   wire [31:0] E_result = 
	(isJAL(DE_instr) | isJALR(DE_instr)) ? DE_PC+4                :
	isLUI(DE_instr)                      ? Uimm(DE_instr)         :
	isAUIPC(DE_instr)                    ? DE_PC + Uimm(DE_instr) : 
        E_aluOut                                                      ;
```

Finally, the Execute stage computes both the result of the operation
(`Eresult`), the address for Load and Store instructions (`addr`) and
passes them to the next stage (as well as the PC, instruction and value
of the second source register):

```
   always @(posedge clk) begin
      if(state[E_bit]) begin
	 EM_PC      <= DE_PC;
	 EM_instr   <= DE_instr;
	 EM_rs2     <= DE_rs2;
	 EM_Eresult <= E_result;
	 EM_addr    <= isStore(DE_instr) ? DE_rs1 + Simm(DE_instr) : 
                                           DE_rs1 + Iimm(DE_instr) ;
      end
   end
   
/******************************************************************************/
   reg [31:0] EM_PC;
   reg [31:0] EM_instr;
   reg [31:0] EM_rs2;
   reg [31:0] EM_Eresult;
   reg [31:0] EM_addr;
/******************************************************************************/
```

Then the two "exception to the rule" signals of the Fetch stage are connected
as follows:

```verilog
   assign jumpOrBranchAddress = E_JumpOrBranchAddr;
   assign jumpOrBranch        = E_JumpOrBranch & state[E_bit];
```

### Memory

### WriteBack


_WIP_


| CPI   | RAYSTONES |
|-------|-----------|
| 5     | 1.589     |


## Step 4: solving hazards by stalling and flushing

### data hazards

### structural hazards
