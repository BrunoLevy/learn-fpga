// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SPI Flash, projected in memory space (readonly)
//
// TODO: QSPI mode

module MappedSPIFlash(
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [17:0]  word_address, // address of the word to be read, offset from 1Mb

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data			    

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg 	       CS_N, // chip select negated (active low)		
    output wire        MOSI, // master out slave in (data to be sent to flash)
    input wire 	       MISO  // master in slave out (data received from flash)
);

   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = busy; // send address and read data done on wstrb
   reg 	      slow_clk;     // =clk/2 (TODO check if/when we need to divide more)
   
   assign  MOSI = sending && cmd_addr[31];
   initial CS_N = 1'b1;
   assign  CLK  = busy && slow_clk;
   
   always @(posedge clk) begin
      slow_clk <= ~slow_clk;
   end

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};
   
   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 //            ------------SPI Flash command: read bytes
	 //            |       -------------------- offset = 1Mb
	 //            |       |           
	 cmd_addr <= {8'h03, 4'b0001,word_address[17:0], 2'b00};
	 snd_bitcount <= 6'd32;
      end else begin
	 if(sending && slow_clk) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b0};
	 end
	 if(receiving && slow_clk) begin
	    rcv_bitcount <= rcv_bitcount - 6'd1;
	    rcv_data <= {rcv_data[30:0],MISO};
	 end
	 if(!busy && slow_clk) begin
	    CS_N <= 1'b1;
	 end
      end
   end

endmodule
