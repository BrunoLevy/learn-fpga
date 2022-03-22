/**
 * Step 3: RAM
 */

`default_nettype none

module SOC (
    input  CLK,        // system clock 
    input  RESET,      // reset button
    output [4:0] LEDS, // system LEDs
    input  RXD,        // UART receive
    output TXD         // UART transmit
);

   wire clock;
   reg [4:0] PC = 0;
   reg [4:0] MEM [0:19];
   initial begin
       MEM[0]  = 5'b00000;
       MEM[1]  = 5'b00001;
       MEM[2]  = 5'b00010;
       MEM[3]  = 5'b00100;
       MEM[4]  = 5'b01000;
       MEM[5]  = 5'b10000;
       MEM[6]  = 5'b10001;
       MEM[7]  = 5'b10010;
       MEM[8]  = 5'b10100;
       MEM[9]  = 5'b11000;
       MEM[10] = 5'b11001;
       MEM[11] = 5'b11010;
       MEM[12] = 5'b11100;
       MEM[13] = 5'b11101;
       MEM[14] = 5'b11110;
       MEM[15] = 5'b11111;
       MEM[16] = 5'b11110;
       MEM[17] = 5'b11100;
       MEM[18] = 5'b11000;
       MEM[19] = 5'b10000;
       MEM[20] = 5'b00000;       
   end

   reg [4:0] leds = 0;
   assign LEDS=leds;

   always @(posedge clock) begin
      leds <= MEM[PC];
      PC <= (RESET || PC==20) ? 0 : (PC+1);
   end


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
   assign clock = slow_CLK[slow_bit];
`else
   assign clock = CLK;
`endif

endmodule
