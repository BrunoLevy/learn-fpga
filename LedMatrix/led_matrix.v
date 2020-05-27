module MessageROM(
   input wire [4:0] address,
   output wire [7:0] data
);

  // TODO: is there a way of initializing directly from
  // a string ?
  reg [7:0] message[31:0];
  initial begin
    message[0]  = "H";
    message[1]  = "e";    
    message[2]  = "l";
    message[3]  = "l";
    message[4]  = "o";
    message[5]  = " ";
    message[6]  = "w";
    message[7]  = "o";
    message[8]  = "r";
    message[9]  = "l";
    message[10] = "d";
    message[11] = "!";
    message[12] = ".";
    message[13] = ".";
    message[14] = ".";
    message[15] = " ";
    message[16] = "H";
    message[17] = "E";    
    message[18] = "L";
    message[19] = "L";
    message[20] = "O";
    message[21] = " ";
    message[22] = "W";
    message[23] = "O";
    message[24] = "R";
    message[25] = "L";
    message[26] = "D";
    message[27] = "!";
    message[28] = ".";
    message[29] = ".";
    message[30] = ".";
    message[31] = " ";
    
  end   
  assign data = message[address];

endmodule


module led_matrix(
   input  wire pclk,
   output wire leds_din,
   output wire leds_cs,
   output wire leds_clk,
   output wire D1,D2,D3,D4,D5
);

  /**********************************************/
  
   // MAX7219 max frequency is 10 MHz,
   // Divide freq by two -> 6 MHz.
   reg[1:0] cnt;
   always @(posedge pclk) begin
      cnt <= cnt + 1;
   end
   wire clk = cnt[1];

  /**********************************************/
  
   assign {D1, D2, D3, D4, D5} = 5'b11111;
  
   wire [4:0] address;
   wire [7:0] data;
   MessageROM message_rom(
       .address(address),
       .data(data)
   );

   Scroller #(.WIDTH(5)) scroller(
      .clk(clk),
      .reset(1'b0),		     
      .enable(1'b1),
      .address(address),
      .data(data),
      .MAX7219_d(leds_din),
      .MAX7219_cs(leds_cs),
      .MAX7219_clk(leds_clk)
   );

endmodule
