# From Blinker to RISC-V

This tutorial is a progressive journey from a simple blinky design to a RISC-V core.

## Prerequisites:

Before starting, you will need to install the following softwares:
- iverilog/icarus (simulation)
```
  sudo apt-get install iverilog
```
- yosys/nextpnr, the toolchain for your board. See [this link](../toolchain.md).

## Step 1: your first blinky

Let us start and create our first blinky ! Our blinky is implemented as VERILOG module,
connected to inputs and outputs, as follows ([step1.v](step1.v)):
```
   module SOC (
       input  CLK,        
       input  RESET,      
       output [4:0] LEDS, 
       input  RXD,        
       output TXD         
   );

   reg [4:0] count = 0;
   always @(posedge CLK) begin
      count <= count + 1;
   end
   assign LEDS = count;
   assign TXD  = 1'b0; // not used for now

   endmodule
```
We call it SOC (System On Chip), which is a big name for a blinky, but
that's what our blinky will be morphed into after all the steps of
this tutorial. Our SOC is connected to the following signals:

- `CLK` (input) is the system clock.
- `LEDS` (output) is connected to the 5 LEDs of the board.
- `RESET` (input) is a reset button. You'll say that the IceStick
   has no button, but in fact ... (we'll talk about that
   later)
- `RXD` and `TXD` (input,output) connected to the FTDI chip that emulates 
   a serial port through USB. We'll also talk about that
   later.

You can synthesize and send the bitstream to the device as follows:
```
$ BOARDS/run_xxx.sh step1.v
```
where `xxx` corresponds to your board.

The five leds will light on... but they are not blinking. Why is this so ?
In fact they are blinking, but it is too fast for you to distinguish anything.

To see something, it is possible to use simulation. To use simulation, we write
a new VERILOG file [bench_iverilog.v](bench_iverilog.v),
with a module `bench` that encapsulates our `SOC`:
```
module bench();
   reg CLK;
   wire RESET = 0; 
   wire [4:0] LEDS;
   reg  RXD = 1'b0;
   wire TXD;

   SOC uut(
     .CLK(CLK),
     .RESET(RESET),
     .LEDS(LEDS),
     .RXD(RXD),
     .TXD(TXD)
   );

   reg[4:0] prev_LEDS = 0;
   initial begin
      CLK = 0;
      forever begin
	 #1 CLK = ~CLK;
	 if(LEDS != prev_LEDS) begin
	    $display("LEDS = %b",LEDS);
	 end
	 prev_LEDS <= LEDS;
      end
   end
endmodule   
```
The module `bench` drives all the signals of our `SOC` (called
`uut` here for "unit under test"). The `forever` loop wiggles
the `CLK` signal and displays the status of the LEDs whenever
it changes.

Now we can start the simulation:
```
  $ iverilog -DBENCH -DBOARD_FREQ=10 bench_iverilog.v step1.v
  $ vvp a.out
```
... but that's a lot to remember, so I created a script for that,
you'll prefer to do:
```
  $ ./run.sh step1.v
```

You will see the LEDs counting. Simulation is precious, it lets
you insert "print" statements (`$display`) in your VERILOG code,
which is not directly possible when you run on the device !

To exit the simulation:
```
  <ctrl><c>
  finish
```
_Note: I developped the first version of femtorv completely on device,
 using only the LEDs to debug because I did not know how to
 use simulation, don't do that, it's stupid !_
 
**Try this** How would you modify `step1.v` to slow it down
sufficiently for one to see the LEDs blinking ?

**Try this** Can you implement a "Knight driver"-like blinking
pattern instead of counting ?

## Step 2: slower blinky

You probably got it right: the blinky can be slowed-down either
by counting on a larger number of bits (and wiring the most
significant bits to the leds), or inserting a "clock divider"
(also called a "gearbox") that counts on a large number
of bits (and driving the counter
with its most significant bit). The second solution is interesting,
because you do not need to modify your design, you just insert
the clock divider between the `CLK` signal of the board and your
design. Then, even on the device you can distinguish what happens
with the LEDs.

To do that, I created a `Clockworks` module in (clockworks.v)[clockworks.v],
that contains the gearbox and a mechanism related with the `RESET` signal (that
I'll talk about later). `Clockworks` is implemented as follows:
```
module Clockworks 
(
   input  CLK,   // clock pin of the board
   input  RESET, // reset pin of the board
   output clk,   // (optionally divided) clock for the design.
   output resetn // (optionally timed) negative reset for the design (more on this later)
);
   parameter SLOW;
...
   reg [SLOW:0] slow_CLK = 0;
   always @(posedge CLK) begin
      slow_CLK <= slow_CLK + 1;
   end
   assign clk = slow_CLK[SLOW];
...
endmodule
```
This divides clock frequency by `2^SLOW`.

The `Clockworks` module is then inserted
between the `CLK` signal of the board
and the design, using an internal `clk`
signal, as follows, in [step2.v](step2.v):

```
`include "clockworks.v"

module SOC (
    input  CLK,        // system clock 
    input  RESET,      // reset button
    output [4:0] LEDS, // system LEDs
    input  RXD,        // UART receive
    output TXD         // UART transmit
);

   wire clk;    // internal clock
   wire resetn; // internal reset signal, goes low on reset
   
   // A blinker that counts on 5 bits, wired to the 5 LEDs
   reg [4:0] count = 0;
   always @(posedge clk) begin
      count <= !resetn ? 0 : count + 1;
   end

   // Clock gearbox (to let you see what happens)
   // and reset circuitry (to workaround an
   // initialization problem with Ice40)
   Clockworks #(
     .SLOW(21) // Divide clock frequency by 2^21
   )CW(
     .CLK(CLK),
     .RESET(RESET),
     .clk(clk),
     .resetn(resetn)
   );
   
   assign LEDS = count;
   assign TXD  = 1'b0; // not used for now   
endmodule
```
It also handles the `RESET` signal. 

Now you can try it on simulation:
```
  $ ./run.sh step2.v
```

As you can see, the counter is now much slower. Try it also on device:
```
  $ BOARDS/run_xxx.sh step2.v
```
Yes, now we can see clearly what happens ! And what about the `RESET`
button ? The IceStick has no button. In fact it has one ! 

[[IceStick_RESET.jpg]]


## Files for all the steps

- [step 1](step1.v): Blinker, too fast, can't see anything
- [step 2](step2.v): Blinker with clockworks
- [step 3](step3.v): Blinker that loads pattern from RAM
- [step 4](step4.v): The instruction decoder
- [step 5](step5.v): The register bank and the state machine
- [step 6](step6.v): The ALU
- [step 7](step7.v): Using the VERILOG assembler
- [step 8](step8.v): Jumps
- [step 9](step9.v): Branches
- [step 10](step10.v): LUI and AUIPC
- [step 11](step11.v): Memory in separate module
- [step 12](step12.v): Subroutines 1 (standard Risc-V instruction set)
- [step 13](step13.v): Size optimization
- [step 14](step14.v): Subroutines 2 (using Risc-V pseudo-instructions)
- [step 15](step15.v): Load
- [step 16](step16.v): Store
- [step 17](step17.v): Memory-mapped devices 
- [step 18](step18.v): Mandelbrot set

_WIP_

- step 19: Faster simulation with Verilator
- step 20: Using the GNU toolchain to compile programs
- step 21: More devices (LED matrix, OLED screen...)
- step 22: Running programs from the SPI Flash
- step 23: Raytracing with the IceStick
