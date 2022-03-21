/**
 * Step 2: simulation of a Blinker
 *         version with five LEDs
 */

`default_nettype none

module SOC (
    input clock,
    output leds_active,
    output [4:0] leds
);
   reg [4:0] count;
   initial begin
      count = 0;
   end
   always @(posedge clock) begin
      count <= count + 1;
   end
   assign leds = count;
   assign leds_active = 1'b1;
endmodule

