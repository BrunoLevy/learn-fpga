// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SPI Flash
//
// TODO: - we could use wmask to read/write directly 16 bits or 32 bits of data
//       - QSPI mode
// DataSheet: https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf

module SPIFlash(
    input wire 	       clk,   // system clock
    input wire 	       rstrb, // read strobe		
    input wire 	       wstrb, // write strobe
    input wire 	       sel,   // select (read/write ignored if low)
    input wire [31:0]  wdata, // data to be written

    output wire        wbusy, // asserted if the driver is busy sending data		
    output wire [31:0] rdata, // data read

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg 	       CS_N, // chip select negated (active low)		
    output wire        MOSI, // master out slave in (data to be sent to flash)
    input wire 	       MISO  // master in slave out (data received from flash)
);

   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [3:0]  rcv_bitcount;
   reg [7:0]  rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     wbusy = busy; // send address and read data done on wstrb
   reg 	      slow_clk;     // =clk/2 (TODO check if/when we need to divide more)
   
   assign  MOSI = sending && cmd_addr[31];
   initial CS_N = 1'b1;
   assign  CLK  = busy && slow_clk;
   
   always @(posedge clk) begin
      slow_clk <= ~slow_clk;
   end

   assign rdata = sel ? {24'b0, rcv_data} : 32'b0;
   
   always @(posedge clk) begin
      if(wstrb && sel) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h03, wdata[23:0]};
	 snd_bitcount <= 6'd32;
      end else begin
	 if(sending && slow_clk) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 4'd8;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b0};
	 end
	 if(receiving && slow_clk) begin
	    rcv_bitcount <= rcv_bitcount - 4'd1;
	    rcv_data <= {rcv_data[6:0],MISO};
	 end
	 if(!busy && slow_clk) begin
	    CS_N <= 1'b1;
	 end
      end
   end

endmodule
