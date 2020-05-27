module Scroller(
    clk,         // 10MHz max
    reset,       // reset frame and char counter
    enable,      // if 0, deactivate display
    address,     // displayed character index (out)
    data,        // displayed character (in)
    MAX7219_d,   // Pins of the MAX7219 (out)
    MAX7219_cs,  //
    MAX7219_clk  //
);
  parameter WIDTH=4;

  input  wire clk;
  input  wire reset;
  input  wire enable;
  output wire [WIDTH-1:0] address;
  input  wire [7:0] data;
  output wire MAX7219_d;
  output wire MAX7219_cs;
  output wire MAX7219_clk;  

  wire do_reset = reset || ((~|data || (data == 13)) && ~|column);

  wire MAX7219_wr;
  wire MAX7219_busy;
  wire [15:0] MAX7219_address_data;
  MAX7219 max7219(
     .clk(clk),
     .address_data(MAX7219_address_data),
     .wr(MAX7219_wr),
     .d_out(MAX7219_d),
     .cs_out(MAX7219_cs),
     .clk_out(MAX7219_clk),
     .busy(MAX7219_busy),
     .reset(do_reset)
  );

  reg[2:0] column;
  reg[31:0] frame;

  // Initialization mechanism, send init sequence every 256 frames
  // (I do that because I am powering the MAX7219 with 3.5V, which
  //  is not enough (normally requires 5V). Sometimes errors happen, 
  //  putting garbage in the control registers).
  wire init = ~|frame[7:0];

  // Previous version:
  //   assign MAX7219_wr = !MAX7219_busy;
  //   and remove all references to wr
  // It works, but the "combinatorial loop" busy->wr
  // is probably not good.

  reg wr; //'write' toggle 
  initial begin
     wr = 1;
  end
  assign MAX7219_wr = wr;
   
  always @(posedge clk) 
  begin
    if(do_reset) begin
       column <= 0;
       frame  <= 0;
       wr     <= 1;
    end else if(MAX7219_busy) begin
       wr <= 0;
    end else if(!wr) begin // Don't know why I need this test ? 'busy' should be on as soon as 'wr' is on ? (but there is a one clock delay ?)
       wr <= 1;
       column <= column + 1;
       if(~|column) begin
	  frame <= frame + 1;
       end
    end
  end

  wire [15:0] init_program = 
    (column == 4'd0)  ? {8'h09, 8'h00} : // decode mode
    (column == 4'd1)  ? {8'h0a, 8'h0f} : // intensity
    (column == 4'd2)  ? {8'h0b, 8'h07} : // scan limit
    (column == 4'd3)  ? {8'h0c, 8'h01} : // shutdown 
    (column == 4'd4)  ? {8'h0f, 8'h00} : // display test
    {8'h00, 8'b00000000} ;
  
 
  // "smooth" char index: 3 lsb's correspond to offset in char.
  wire [WIDTH+3-1:0] char_index_and_offset = (frame >> 10);
   
  // "extended column" index: 0..7 in char1, 8..15 in char2
  wire [4:0] ecolumn = column + char_index_and_offset[2:0];
   
  // char index from extended column index
  assign address = (ecolumn >= 8) ? 
       char_index_and_offset[WIDTH+3-1:3]+1 : 
       char_index_and_offset[WIDTH+3-1:3]   ;
     
  wire [10:0] font_address = {data, ecolumn[2:0]};
  wire [7:0]  font_rom_data;
  FontROM font_rom(
    .address(font_address),
    .data(font_rom_data),
    .clk(clk)
  );

  // send column to MAX7219 (or init sequence every 256 frames)
  //              column+1 because MAX7219 uses 1-based indices   
  wire [15:0] display_program = { column+1, font_rom_data}; 
  assign MAX7219_address_data = init ? init_program : display_program;

endmodule
