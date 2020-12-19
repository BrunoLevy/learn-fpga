// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: driver for LEDs (does nearly nothing !)
//

module LEDDriver(
    input wire 	       clk,   // system clock
    input wire 	       rstrb, // read strobe		
    input wire 	       wstrb, // write strobe
    input wire 	       sel,   // select (read/write ignored if low)
    input wire [31:0]  wdata, // data to be written
    output wire [31:0] rdata, // read data
    output wire [3:0]   LED    // LED pins
);

   reg [3:0] led_state;
   assign LED = led_state;
   
   initial begin
      led_state = 4'b0000;
   end
   
   assign rdata = (sel ? {28'b0, led_state} : 32'b0);
   
   always @(posedge clk) begin
      if(sel && wstrb) begin
	 led_state <= wdata;
	 `bench($display("****************** LEDs = %b  0x%h %d", wdata[3:0],wdata,$signed(wdata)));
      end
   end
   
endmodule
