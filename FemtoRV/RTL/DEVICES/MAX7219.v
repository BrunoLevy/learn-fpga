// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: driver for MAX7219 led matrix display

module MAX7219(
    input wire 	      clk,      // system clock
    input wire 	      wstrb,    // write strobe 
    input wire 	      sel,      // write ignored if low
    input wire [31:0] wdata,    // data to be written

    output wire       wbusy,    // asserted if the driver is busy sending data

                           // MAX7219 pins
    output wire	      DIN, // data in
    output wire	      CLK, // clock
    output wire	      CS   // chip select 
);
  
   reg [2:0] divider;
   always @(posedge clk) begin
      divider <= divider + 1;
   end
   
   // clk=60MHz, slow_clk=60/8 MHz (max = 10 MHz)
   wire       slow_clk = (divider == 3'b000);
   reg[4:0]   bitcount; // 0 means idle
   reg[15:0]  shifter;

   assign DIN  = shifter[15];
   wire sending = |bitcount;
   assign wbusy = sending;   
   assign CS  = !sending;
   assign CLK = sending && slow_clk;

   always @(posedge clk) begin
      if(wstrb) begin
	 if(sel) begin
	    shifter <= wdata[15:0];
	    bitcount <= 16;
	 end
      end else begin
	 if(sending &&  slow_clk) begin
            bitcount <= bitcount - 5'd1;
            shifter <= {shifter[14:0], 1'b0};
	 end
      end
   end


   
endmodule
