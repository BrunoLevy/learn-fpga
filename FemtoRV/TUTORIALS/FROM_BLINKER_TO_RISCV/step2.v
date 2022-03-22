/**
 * Step 2: Blinker (slower version)
 * DONE
 */

`default_nettype none

module SOC (
    input  CLK,        // system clock 
    input  RESET,      // reset button
    output [4:0] LEDS, // system LEDs
    input  RXD,        // UART receive
    output TXD         // UART transmit
);

// Decceleration factor to make it possible
// to observe what happens.
// Simulation is approx. 16 times slower than
// actual device.
`ifdef BENCH
   localparam slow_bit=17;
`else
   localparam slow_bit=21;
`endif

// Comment to deactivate clock decceleration.
`define SLOW

`ifdef SLOW
   reg [slow_bit:0] slow_CLK = 0;
   always @(posedge CLK) slow_CLK <= slow_CLK + 1;
   wire clock = slow_CLK[slow_bit];
`else
   wire clock = CLK;
`endif

// A blinker that counts on 5 bits, wired to the 5 LEDs
   reg [4:0] count = 0;
   always @(posedge clock) begin
      count <= RESET ? 0 : count + 1;
   end
   assign LEDS = count;
   
endmodule
