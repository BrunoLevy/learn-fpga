// Simple driver for MAX7219 led matrix
// Bruno Levy, May 2020

module MAX7219 (
   input  wire clk,                 // Max 10 MHz
   input  wire reset,
   input  wire [15:0] address_data, // a7...a0 d7...d0
   input  wire wr,                  // raise to send data
   output wire d_out,               // MAX7219 D pin
   output wire cs_out,              // MAX7219 CS pin
   output wire clk_out,             // MAX7219 CLK pin
   output wire busy                 // 1 if currently sending data
);

   reg[4:0]  bitcount; // 0 means idle
   reg[15:0] shifter;

   assign d_out   = shifter[15];
   wire sending = |bitcount;
   assign cs_out  = !sending;
   assign busy    = sending;
   assign clk_out = sending && clk;

   always @(posedge clk)
   begin
     if(reset) begin
        shifter <= 0;
        bitcount <= 0;
     end else begin
        if(wr) begin
           shifter <= address_data;
           bitcount <= 16;
        end else if(sending) begin
           bitcount <= bitcount - 4'd1;
           shifter <= { shifter[14:0], 1'b0 };
        end
     end
   end

endmodule

