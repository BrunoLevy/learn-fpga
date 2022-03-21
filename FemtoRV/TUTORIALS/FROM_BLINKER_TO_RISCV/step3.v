/**
 * Step 3: simulation of a Blinker
 *         version with five LEDs
 *         slower version
 */

`default_nettype none

module SOC (
    input clock,
    output leds_active,
    output [4:0] leds
);
   reg [21:0] count;
   initial begin
      count = 0;
   end
   always @(posedge clock) begin
      count <= count + 1;
   end
   assign leds = count[21:17];
   assign leds_active = 1'b1;
endmodule

