// Reads a character on the virtual RX pin of the USB, and
// displays it on the MAX2719 led matrix.

  /**********************************************/

module LineBuffer(
   input wire clk,
   input wire reset,
   input wire [7:0] character,
   input wire wr,
   input  wire [4:0] address,
   output wire [7:0] data
);
   reg[4:0] top;
   reg[7:0] buffer[31:0];
   always @(posedge clk)
   begin
      if(reset) begin
         top <= 0;
	 buffer[0] <= " ";
	 buffer[1] <= 0;	 
      end else if(wr) begin
         if(character == 10) begin
            top <= 0;
   	    buffer[0] <= " ";
   	    buffer[1] <= 0;	    
	 end else if(character == 8) begin
	    buffer[top-1] <= 0;
	    top <= top-1;
	 end else begin
            top <= top + 1;
            buffer[top]   <= character;
	    buffer[top+1] <= 0;
         end	    
      end
   end
   assign data = buffer[address];
endmodule

/****************************************************/

module led_terminal(
   input  wire pclk,
   output wire leds_din,
   output wire leds_cs,
   output wire leds_clk,
   output wire D1, D2, D3, D4, D5,
   input  wire RXD,
   output wire TXD
);

  /**********************************************/

   reg[7:0] character;
   wire [4:0] address;
   wire [7:0] data;
   wire wr;
   LineBuffer buffer(
      .clk(pclk),
      .reset(1'b0),
      .character(character),
      .wr(wr),
      .address(address),
      .data(data)
   );

   reg  uart0_wr;
   wire uart0_busy;
   wire uart0_valid;
   wire [7:0] uart0_data;
   
   buart uart0 (
     .clk(pclk),
     .resetq(1'b1),
     .rx(RXD),
     .tx(TXD),
     .rd(1'b1),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(character),
     .rx_data(uart0_data)
   );

   assign wr = uart0_wr;
   always @(posedge pclk) begin
      if(uart0_valid) begin
         character <= uart0_data;
  	 uart0_wr <= 1;
      end else begin
         uart0_wr <= 0;
      end 
   end
 
   /*******************************************/

   // Divide freq by two -> 6 MHz
   reg[1:0] cnt;
   always @(posedge pclk) begin
      cnt <= cnt + 1;
   end
   wire clk = cnt[1];
   
  /**********************************************/

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
