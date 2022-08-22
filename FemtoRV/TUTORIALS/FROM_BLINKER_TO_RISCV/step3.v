TAGADA

/**
 * Step 3: Display a led pattern "animation" stored in BRAM.
 * DONE*
 */

`default_nettype none
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
   
   reg [4:0] PC = 0;
   reg [4:0] MEM [0:20];
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

   always @(posedge clk) begin
      leds <= MEM[PC];
      PC <= (!resetn || PC==20) ? 0 : (PC+1);
   end

   // Gearbox and reset circuitry.
   Clockworks #(
     .SLOW(21) // Divide clock frequency by 2^21
   )CW(
     .CLK(CLK),
     .RESET(RESET),
     .clk(clk),
     .resetn(resetn)
   );
   
   assign TXD  = 1'b0; // not used for now   
endmodule
