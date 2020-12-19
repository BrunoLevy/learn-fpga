// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: driver for SDCard (does nearly nothing,
// for now it is just an interface for software bitbanging,
// see FIRMWARE/LIBFEMTORV32/spi_sd.c)
//

module SDCard(
    input wire 	       clk,   // system clock
    input wire 	       rstrb, // read strobe		
    input wire 	       wstrb, // write strobe
    input wire 	       sel,   // select (read/write ignored if low)
    input wire [31:0]  wdata, // data to be written
    output wire [31:0] rdata, // read data

    output wire        MOSI,
    input wire 	       MISO,
    output wire	       CS_N,
    output wire        CLK
);
   reg [2:0] state; // CS_N,CLK,MOSI

   assign CS_N = state[2];
   assign CLK  = state[1];
   assign MOSI = state[0];
   
   initial begin
      state = 3'b100;
   end
   
   assign rdata = (sel ? {31'b0, MISO} : 32'b0);
   
   always @(posedge clk) begin
      if(sel && wstrb) begin
	 state <= wdata[2:0];
      end
   end
   
endmodule
