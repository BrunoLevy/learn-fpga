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

