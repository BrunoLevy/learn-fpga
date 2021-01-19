// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SPI Flash, projected in memory space (readonly)
//    DUAL IO mode (reads 32 bits in 44 cycles)
//    Note: unfortunately, QUAD IO is not possible because the IO2 and IO3 pins
//    are not wire on the IceStick (one may solder a tiny wire and plug it 
//    to a GPIO pin but I haven't soldering skills for things of that size !!)
//
// TODO: go faster with XIP mode and dummy cycles customization
// - send write enable command                   (06h)
// - send write volatile config register command (08h REG)
//   REG=dummy_cycles[7:4]=4'b0100 XIP[3]=1'b1 reserved[2]=1'b0 wrap[1:0]=2'b11
//     (4 dummy cycles, works at up to 90 MHz according to datasheet)
// -> 32 cycles (@: 12  dummy: 4  data: 16
//
// DataSheets:
// https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf?rev=27fc6016fc5249adb4bb8f221e72b395
// https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf (not the same chip, mostly compatible, datasheet is easier to read)


module MappedSPIFlash(
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [17:0]  word_address, // offset from 1Mb

    output wire [31:0] rdata, // data read
    output wire        rbusy, // asserted if busy receiving data			    

    output wire        CLK,  // clock
    output reg 	       CS_N, // chip select negated (active low)		
    inout wire [1:0]   IO    // two bidirectional IO pins
);

   
   reg [4:0]  snd_clock; // send clock, 2 bits per clock (dual IO)
   reg [47:0] cmd_addr;  // command + address shift register
   reg [4:0]  rcv_clock; // receive clock, 2 bits per clock (dual IO)
   reg [31:0] rcv_data;  // received data shift register
   wire       sending   = (snd_clock != 0);
   wire       receiving = (rcv_clock != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 

   // The two data pins IO0 (=MOSI) and IO1 (=MISO) used in bidirectional mode.
   reg IO_oe = 1'b1;
   wire [1:0] IO_out = cmd_addr[39:38];
   wire [1:0] IO_in  = IO;
   assign IO = IO_oe ? IO_out : 2'bZZ;
   
   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && clk; // CLK needs to be disabled when not active.

   // since least significant bytes are read first, we need to swizzle...
   assign rdata={rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   localparam CMD=8'hbb; // Command = Fast read dual IO
   localparam CCMMDD = { // Dual IO mode not active yet, double the bits !
         CMD[7],CMD[7],CMD[6],CMD[6],CMD[5],CMD[5],CMD[4],CMD[4],
         CMD[3],CMD[3],CMD[2],CMD[2],CMD[1],CMD[1],CMD[0],CMD[0]
   }; 

   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 //            .--------------------------- SPI Flash command
	 //            |       .------------------- offset = 1Mb    
	 //            |       |                                 
	 cmd_addr <= {CCMMDD, 4'b0001,word_address[17:0], 2'b00};
	 snd_clock <= 5'd20; // 40 bits to send (= 20 clocks)
	 IO_oe <= 1'b1;
      end else begin
	 if(sending) begin
	    if(snd_clock == 1) begin
	       rcv_clock <= 5'd24; // 32 bits (= 16 clocks) + 8 dummy clocks
	       IO_oe <= 1'b0;            
	    end
	    snd_clock <= snd_clock - 5'd1;
	    cmd_addr <= {cmd_addr[37:0],2'b00};
	 end
	 if(receiving) begin
	    rcv_clock <= rcv_clock - 5'd1;
	    rcv_data <= {rcv_data[29:0],IO_in};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end

endmodule
