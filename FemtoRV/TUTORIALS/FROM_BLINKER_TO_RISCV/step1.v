/**
 * Step 1: simulation of a Blinker
 */

`default_nettype none

module SOC (
    input clock,
    output leds_active,
    output [4:0] leds
);
   reg count;
   initial begin
      count = 0;
   end
   always @(posedge clock) begin
      count <= ~count;
   end
   assign leds = {4'b0, count};
   assign leds_active = 1'b1;
endmodule

