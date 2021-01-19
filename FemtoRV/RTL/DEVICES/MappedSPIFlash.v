// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SPI Flash, projected in memory space (readonly)
//
// DataSheets:
// https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf?rev=27fc6016fc5249adb4bb8f221e72b395
// https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf (easier to read)


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

   wire MISO_out;
   wire MISO_in;
   wire MISO_oe;
   
   assign MISO = MISO_oe ? MISO_out : 1'bZ; 
   assign MISO_in = MISO;                   

   
   reg [4:0]  snd_2bitcount; // twice snd bitcount
   reg [47:0] cmd_addr;
   reg [4:0]  rcv_2bitcount; // twice rcv bitcount
   reg [31:0] rcv_data;
   wire       sending   = (snd_2bitcount != 0);
   wire       receiving = (rcv_2bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 

   reg oe;

   assign  MOSI_oe  = oe;
   assign  MOSI_out = cmd_addr[38];

   assign  MISO_oe  = oe; 
   assign  MISO_out = cmd_addr[39];
   
   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   localparam CMD=8'hbb; // Command = Fast read dual IO
   localparam CCMMDD = { // Command with double bits (dual IO mode not active yet)
         CMD[7],CMD[7],CMD[6],CMD[6],CMD[5],CMD[5],CMD[4],CMD[4],
         CMD[3],CMD[3],CMD[2],CMD[2],CMD[1],CMD[1],CMD[0],CMD[0]
   }; 

   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 //            .--------------------------- SPI Flash command: fast read bytes
	 //            |       .------------------- offset = 1Mb    
	 //            |       |                                 
	 //            |       |                                 
	 cmd_addr <= {CCMMDD, 4'b0001,word_address[17:0], 2'b00};
	 snd_2bitcount <= 5'd20;
	 oe <= 1'b1;
      end else begin
	 if(sending) begin
	    if(snd_2bitcount == 1) begin
	       rcv_2bitcount <= 5'd24; // 8 dummy cycles (=16 dummy bits) + 32 bits
	       oe <= 1'b0;            
	    end
	    snd_2bitcount <= snd_2bitcount - 5'd1;
	    cmd_addr <= {cmd_addr[37:0],2'b00};
	 end
	 if(receiving) begin
	    rcv_2bitcount <= rcv_2bitcount - 5'd1;
	    rcv_data <= {rcv_data[29:0],MISO_in,MOSI_in};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end

endmodule
