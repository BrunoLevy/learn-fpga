
`define BIDIRECTIONAL
// Comment-out for monodirectional mode (saves 34 cells)
//   Bidirectional: 155 cells
// Monodirectional: 121 cells

// ---------------- Decoder 1 hex digit in ASCII -> 5 bits binary -----------
module decoder (
    input  [7:0] data,
    output [4:0] leds		
);
/*
   assign leds =
	   (data >= 8'h30 && data <= 8'h39) ? data - 8'h30 : 
	   (data >= 8'h61 && data <= 8'h66) ? data - 8'h61 + 8'd10 : 
           8'h00
           ;
*/
   assign leds = data[4:0];
endmodule   

// -------------------------- Main module -----------------------------------
module serial (
    input  pclk,
    output led1, led2, led3, led4, led5,
    output TXD, 
    input  RXD,
    input  resetq	       
);

  wire uart0_valid;
  wire [7:0] uart0_data;
  reg  [7:0] data;
  
  decoder _decoder0(
     .data(data),
     .leds({ led1,led2,led3,led4,led5 })		     
  );
   
   
`ifdef BIDIRECTIONAL
  reg  uart0_wr;
  wire uart0_busy;
  buart _uart0 (
     .clk(pclk),
     .resetq(1'b1),
     .rx(RXD),
     .tx(TXD),
     .rd(1'b1),
     .wr(uart0_wr),
     .valid(uart0_valid),
     .busy(uart0_busy),
     .tx_data(data),
     .rx_data(uart0_data)
  );
  
  always @(posedge pclk) begin
     if(uart0_valid) begin
        data <= uart0_data;
	uart0_wr <= 1; 
     end else begin
        uart0_wr <= 0; 
     end
  end
  
`else

  rxuart _uart0 (
     .clk(pclk),
     .resetq(1'b1),
     .uart_rx(RXD),
     .rd(1'b1),
     .valid(uart0_valid),
     .data(uart0_data)
  );

  always @(posedge pclk) begin
     if(uart0_valid) begin
        data <= uart0_data;
     end 
  end

`endif


 
endmodule

//  miniterm.py --dtr=0 /dev/ttyUSB1 115200
