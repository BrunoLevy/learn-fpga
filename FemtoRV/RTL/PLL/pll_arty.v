 module femtoPLL #(
    parameter freq = 50
 ) (
    input wire pclk,
    output wire clk
 );

 wire clk_feedback;
 wire clk_internal;

 PLLE2_ADV #(
    .BANDWIDTH("OPTIMIZED"),    // OPTIMIZED, HIGH, LOW
    .CLKFBOUT_MULT(8),    // Multiply value for all CLKOUT (2-64)
    .CLKFBOUT_PHASE(0.0), // Phase offset in degrees of CLKFB, (-360-360)
    .CLKIN1_PERIOD(10.0), // Input clock period in ns to ps resolution
    .CLKOUT0_DIVIDE(8*100/freq),  
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),
    .DIVCLK_DIVIDE(1),    // Master division value , (1-56)
    .REF_JITTER1(0.0),    // Reference input jitter in UI (0.000-0.999)
    .STARTUP_WAIT("FALSE")    // Delayu DONE until PLL Locks, ("TRUE"/"FALSE")
 ) genclock(
     .CLKOUT0(clk_internal),
     .CLKFBOUT(clk_feedback), // 1-bit output, feedback clock
     .CLKIN1(pclk),
     .PWRDWN(1'b0),
     .RST(1'b0),
     .CLKFBIN(clk_feedback)    // 1-bit input, feedback clock
 );

 BUFG bufg(
     .I(clk_internal),
     .O(clk)
 );

 endmodule
