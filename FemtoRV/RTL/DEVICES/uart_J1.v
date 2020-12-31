// Borrowed from swapforth by James Bowman: 
//   https://github.com/jamesbowman/swapforth

`default_nettype none

`ifndef CLKFREQ
   `define CLKFREQ   12000000    // frequency of incoming signal 'clk'
`endif

`define BAUD      115200

// Simple baud generator for transmitter
// ser_clk pulses at 115200 Hz

module baudgen(
  input wire clk,
  output wire ser_clk);

  localparam lim = (`CLKFREQ / `BAUD) - 1; 
  localparam w = $clog2(lim);
  wire [w-1:0] limit = lim;
  reg [w-1:0] counter;
  assign ser_clk = (counter == limit);

  always @(posedge clk)
    counter <= ser_clk ? 0 : (counter + 1);
endmodule

// For receiver, a similar baud generator.
//
// Need to restart the counter when the transmission starts
// Generate 2X the baud rate to allow sampling on bit boundary
// So ser_clk pulses at 2*115200 Hz

module baudgen2(
  input wire clk,
  input wire restart,
  output wire ser_clk);

  localparam lim = (`CLKFREQ / (2 * `BAUD)) - 1; 
  localparam w = $clog2(lim);
  wire [w-1:0] limit = lim;
  reg [w-1:0] counter;
  assign ser_clk = (counter == limit);

  always @(posedge clk)
    if (restart)
      counter <= 0;
    else
      counter <= ser_clk ? 0 : (counter + 1);

endmodule

/*

-----+     +-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+----
     |     |     |     |     |     |     |     |     |     |     |     |
     |start|  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  |stop1|stop2|
     |     |     |     |     |     |     |     |     |     |     |  ?  |
     +-----+-----+-----+-----+-----+-----+-----+-----+-----+           +

*/

module uart(
   input wire clk,
   input wire resetq,

   output wire uart_busy,       // High means UART is transmitting
   output reg uart_tx,          // UART transmit wire

   input wire uart_wr_i,        // Raise to transmit byte
   input wire [7:0] uart_dat_i
);
  reg [3:0] bitcount;           // 0 means idle, so this is a 1-based counter
  reg [8:0] shifter;

  assign uart_busy = |bitcount;
  wire sending = |bitcount;

  wire ser_clk;

  baudgen _baudgen(
    .clk(clk),
    .ser_clk(ser_clk));

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      uart_tx <= 1;
      bitcount <= 0;
      shifter <= 0;
    end else begin
      if (uart_wr_i) begin
        { shifter, uart_tx } <= { uart_dat_i[7:0], 1'b0, 1'b1 };
        bitcount <= 1 + 8 + 1;    // 1 start, 8 data, 1 stop
      end else if (ser_clk & sending) begin
        { shifter, uart_tx } <= { 1'b1, shifter };
        bitcount <= bitcount - 4'd1;
      end
    end
  end

endmodule

module rxuart(
   input wire clk,
   input wire resetq,
   input wire uart_rx,      // UART recv wire
   input wire rd,           // read strobe
   output wire valid,       // has data 
   output wire [7:0] data); // data
  reg [4:0] bitcount;
  reg [7:0] shifter;

  // bitcount == 11111: idle
  //             0-17:  sampling incoming bits
  //             18:    character received

  // On starting edge, wait 3 half-bits then sample, and sample every 2 bits thereafter

  wire idle = &bitcount;
  assign valid = (bitcount == 18);

  wire sample;
  reg [2:0] hh = 3'b111;
  wire [2:0] hhN = {hh[1:0], uart_rx};
  wire startbit = idle & (hhN[2:1] == 2'b10);
  wire [7:0] shifterN = sample ? {hh[1], shifter[7:1]} : shifter;

  wire ser_clk;

  baudgen2 _baudgen(
    .clk(clk),
    .restart(startbit),
    .ser_clk(ser_clk));

  reg [4:0] bitcountN;
  always @*
    if (startbit)
      bitcountN = 0;
    else if (!idle & !valid & ser_clk)
      bitcountN = bitcount + 5'd1;
    else if (valid & rd)
      bitcountN = 5'b11111;
    else
      bitcountN = bitcount;

  // 3,5,7,9,11,13,15,17
  assign sample = (|bitcount[4:1]) & bitcount[0] & ser_clk;
  assign data = shifter;

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      hh <= 3'b111;
      bitcount <= 5'b11111;
      shifter <= 0;
    end else begin
      hh <= hhN;
      bitcount <= bitcountN;
      shifter <= shifterN;
    end
  end
endmodule

module buart(
   input wire clk,
   input wire resetq,
   input wire rx,           // recv wire
   output wire tx,          // xmit wire
   input wire rd,           // read strobe
   input wire wr,           // write strobe
   output wire valid,       // has recv data 
   output wire busy,        // is transmitting
   input wire [7:0] tx_data,
   output wire [7:0] rx_data // data
);
  rxuart _rx (
     .clk(clk),
     .resetq(resetq),
     .uart_rx(rx),
     .rd(rd),
     .valid(valid),
     .data(rx_data));
  uart _tx (
     .clk(clk),
     .resetq(resetq),
     .uart_busy(busy),
     .uart_tx(tx),
     .uart_wr_i(wr),
     .uart_dat_i(tx_data));
endmodule
