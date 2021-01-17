// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SPI Flash, projected in memory space (readonly)
// Currently using: fast read dual input
// TODO: fast read dual IO 
// DataSheet: https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf

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
    inout  wire        MISO  // master in slave out (data received from flash)
);

   wire MOSI_out;
   wire MOSI_in;
   wire MOSI_oe;

   assign MOSI = MOSI_oe ? MOSI_out : 1'bZ; 
   assign MOSI_in = MOSI;                   
   
   reg [5:0]  snd_bitcount;
   reg [39:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 

   assign  MOSI_oe = !receiving;   
   assign  MOSI_out = sending && cmd_addr[39];

   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 //            .---------------------- SPI Flash command: fast read dual input
	 //            |       .----------------------------------------- offset = 1Mb    
	 //            |       |                                    .---- 8 dummy bits
	 //            |       |                                    |   (for fast read)
	 cmd_addr <= {8'h3b, 4'b0001,word_address[17:0], 2'b00, 8'b00000000};
	 snd_bitcount <= 6'd40;
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[38:0],1'b0};
	 end
	 if(receiving) begin
	    rcv_bitcount <= rcv_bitcount - 6'd2;
	    rcv_data <= {rcv_data[29:0],MISO,MOSI_in};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end

endmodule
