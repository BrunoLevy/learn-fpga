module blink (
    input clock,
    output led1, led2, led3, led4, led5
);

   localparam BITS = 25;
   reg [BITS-1:0] counter;

   always@(posedge clock) begin
      counter <= counter + 1;
   end

   assign {led1, led2, led3, led4, led5} = counter[BITS-1 : BITS-5];

endmodule