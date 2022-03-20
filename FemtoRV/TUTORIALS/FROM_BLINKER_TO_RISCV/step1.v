/**
 * Step 1: simulation of a Blinker
 * Usage:
 *    iverilog step1.v
 *    vvp a.out
 *    to exit: <ctrl><c> then finish
 */

`default_nettype none

module Blink (
    input clock,
    output led
);
   reg count;
   initial begin
      count = 0;
   end
   always @(posedge clock) begin
      count <= ~count;
   end
   assign led = count;
endmodule

module bench();
   reg clock;
   wire led;

   Blink uut(
     .clock(clock),
     .led(led)	     
   );
   
   initial begin
      clock = 0;
      forever begin
	 #1 clock = ~clock;
	 $display("LED = %b",led);
      end
   end
   
endmodule   
   
