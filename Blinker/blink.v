module blink (
    input clock,
    output led1, led2, led3, led4, led5
);

localparam DIVIDER_BITS = 20;

reg[DIVIDER_BITS-1:0] freq_divider;
reg[4:0] counter;

assign led1 = counter[4];
assign led2 = counter[3];
assign led3 = counter[2];
assign led4 = counter[1];
assign led5 = counter[0];

always@(posedge clock)
begin
   freq_divider <= freq_divider + 1;
end

always@(posedge freq_divider[DIVIDER_BITS-1])
begin
   counter <= counter + 1;
end

endmodule