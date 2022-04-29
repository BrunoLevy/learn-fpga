// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//       Matthias Koch, 2021
//
// This file: driver for SPI Flash, projected in memory space (readonly)
//
// TODO: go faster with XIP mode and dummy cycles customization
// - send write enable command                   (06h)
// - send write volatile config register command (08h REG)
//   REG=dummy_cycles[7:4]=4'b0100 XIP[3]=1'b1 reserved[2]=1'b0 wrap[1:0]=2'b11
//     (4 dummy cycles, works at up to 90 MHz according to datasheet)
//
// DataSheets:
// https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf?rev=27fc6016fc5249adb4bb8f221e72b395
// https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf (not the same chip, mostly compatible, datasheet is easier to read)

// The one on the ULX3S: https://www.issi.com/WW/pdf/25LP-WP128F.pdf
//  this one supports quad-SPI mode, IO0=SI, IO1=SO, IO2=WP, IO3=Hold/Reset

// There are four versions (from slowest to fastest)
//
// Version (used command)          | cycles per 32-bits read | Specificity           |
// ----------------------------------------------------------|-----------------------|
// SPI_FLASH_READ                  | 64 slow (50 MHz)        | Standard              |
// SPI_FLASH_FAST_READ             | 72 fast (100 MHz)       | Uses dummy cycles     |
// SPI_FLASH_FAST_READ_DUAL_OUTPUT | 56 fast                 | Reverts MOSI          |
// SPI_FLASH_FAST_READ_DUAL_IO     | 44 fast                 | Reverts MISO and MOSI |

// One can go even faster by configuring number of dummy cycles (can save up to 4 cycles per read) 
// and/or using XIP mode (that just requires the address to be sent, saves 16 cycles per 32-bits read)
// (I tried both without success). This may require another mechanism to change configuration register.
//
// Most chips support a QUAD IO mode, using four bidirectional pins,
// however, is not possible because the IO2 and IO3 pins
// are not wired on the IceStick (one may solder a tiny wire and plug it 
// to a GPIO pin but I haven't soldering skills for things of that size !!)
// It is a pity, because one could go really fast with these pins !

// Macros to select version and number of dummy cycles based on the board.

`ifdef ICE_STICK
 `define SPI_FLASH_FAST_READ_DUAL_IO
 `define SPI_FLASH_CONFIGURED
`endif

`ifdef ICE_BREAKER
 `define SPI_FLASH_FAST_READ_DUAL_IO
 `define SPI_FLASH_DUMMY_CLOCKS 4 // Winbond SPI chips on icebreaker uses 4 dummy clocks
 `define SPI_FLASH_CONFIGURED
`endif

`ifdef ULX3S
 `define SPI_FLASH_FAST_READ // TODO check whether dual IO mode can be done / dummy clocks
 `define SPI_FLASH_CONFIGURED
`endif

`ifdef ARTY
 `define SPI_FLASH_READ
 `define SPI_FLASH_CONFIGURED
`endif

`ifdef ICE_SUGAR_NANO
 `define SPI_FLASH_READ
 `define SPI_FLASH_CONFIGURED
`endif

`ifndef SPI_FLASH_DUMMY_CLOCKS
 `define SPI_FLASH_DUMMY_CLOCKS 8
`endif

`ifndef SPI_FLASH_CONFIGURED // Default: using slowest / simplest mode (command $03)
 `define SPI_FLASH_READ
`endif

/********************************************************************************************************************************/

`ifdef SPI_FLASH_READ
module MappedSPIFlash( 
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [19:0]  word_address, // address of the word to be read

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data			    

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg         CS_N, // chip select negated (active low)		
    output wire        MOSI, // master out slave in (data to be sent to flash)
    input  wire        MISO  // master in slave out (data received from flash)
);

   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 
   
   assign  MOSI  = cmd_addr[31];
   initial CS_N  = 1'b1;
   assign  CLK   = !CS_N && !clk; // CLK needs to be inverted (sample on posedge, shift of negedge) 
                                  // and needs to be disabled when not sending/receiving (&& !CS_N).

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};
   
   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h03, 2'b00,word_address[19:0], 2'b00};
	 snd_bitcount <= 6'd32;
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b1};
	 end
	 if(receiving) begin
	    rcv_bitcount <= rcv_bitcount - 6'd1;
	    rcv_data <= {rcv_data[30:0],MISO};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end
endmodule
`endif

/********************************************************************************************************************************/

`ifdef SPI_FLASH_FAST_READ
module MappedSPIFlash( 
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [19:0]  word_address, // address of the word to be read

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data			    

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg         CS_N, // chip select negated (active low)		
    output wire        MOSI, // master out slave in (data to be sent to flash)
    input  wire        MISO  // master in slave out (data received from flash)
);

   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 
   
   assign  MOSI  = cmd_addr[31];
   initial CS_N  = 1'b1;
   assign  CLK   = !CS_N && !clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};
   
   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h0b, 2'b00,word_address[19:0], 2'b00};
	 snd_bitcount <= 6'd40; // TODO: check dummy clocks
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b1};
	 end
	 if(receiving) begin
	    rcv_bitcount <= rcv_bitcount - 6'd1;
	    rcv_data <= {rcv_data[30:0],MISO};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end
endmodule
`endif

/********************************************************************************************************************************/

`ifdef SPI_FLASH_FAST_READ_DUAL_OUTPUT
module MappedSPIFlash( 
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [19:0]  word_address, // address of the word to be read

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data			    

		             // SPI flash pins
    output wire        CLK,  // clock
    output reg 	       CS_N, // chip select negated (active low)		
    inout  wire        MOSI, // master out slave in (data to be sent to flash)
    input  wire        MISO  // master in slave out (data received from flash)
);

   wire MOSI_out;
   wire MOSI_in;
   wire MOSI_oe;

   assign MOSI = MOSI_oe ? MOSI_out : 1'bZ; 
   assign MOSI_in = MOSI;                   
   
   reg [5:0]  snd_bitcount;
   reg [31:0] cmd_addr;
   reg [5:0]  rcv_bitcount;
   reg [31:0] rcv_data;
   wire       sending   = (snd_bitcount != 0);
   wire       receiving = (rcv_bitcount != 0);
   wire       busy = sending | receiving;
   assign     rbusy = !CS_N; 

   assign  MOSI_oe = !receiving;   
   assign  MOSI_out = sending && cmd_addr[31];

   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && !clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h3b, 2'b00,word_address[19:0], 2'b00};
	 snd_bitcount <= 6'd40; // TODO: check dummy clocks
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b1};
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
`endif

/********************************************************************************************************************************/

`ifdef SPI_FLASH_FAST_READ_DUAL_IO

module MappedSPIFlash( 
    input wire 	       clk,          // system clock
    input wire 	       rstrb,        // read strobe		
    input wire [19:0]  word_address, // address to be read

		      
    output wire [31:0] rdata, // data read
    output wire        rbusy, // asserted if busy receiving data 

    output wire        CLK,  // clock
    output reg 	       CS_N, // chip select negated (active low)		
    inout wire [1:0]   IO    // two bidirectional IO pins
);

   reg [4:0]  clock_cnt; // send/receive clock, 2 bits per clock (dual IO)
   reg [39:0] shifter;   // used for sending and receiving

   reg 	      dir; // 1 if sending, 0 otherwise

   wire       busy      = (clock_cnt != 0);
   wire       sending   = (dir  && busy);
   wire       receiving = (!dir && busy);
   assign     rbusy     = !CS_N; 

   // The two data pins IO0 (=MOSI) and IO1 (=MISO) used in bidirectional mode.
   reg IO_oe = 1'b1;
   wire [1:0] IO_out = shifter[39:38];
   wire [1:0] IO_in  = IO;
   assign IO = IO_oe ? IO_out : 2'bZZ;
   
   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && !clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata={shifter[7:0],shifter[15:8],shifter[23:16],shifter[31:24]};

   // Duplicates the bits (used because when sending command, dual IO is
   // not active yet, and I do not want to have a separate shifter for
   // the command and for the args...).
   function [15:0] bbyyttee;
      input [7:0] x;
      begin
	 bbyyttee = {
	     x[7],x[7],x[6],x[6],x[5],x[5],x[4],x[4],
	     x[3],x[3],x[2],x[2],x[1],x[1],x[0],x[0]
	 }; 	 
      end
   endfunction

   always @(posedge clk) begin
      if(rstrb) begin
	 CS_N  <= 1'b0;
	 IO_oe <= 1'b1;
	 dir   <= 1'b1;
	 shifter <= {bbyyttee(8'hbb), 2'b00, word_address[19:0], 2'b00};
	 clock_cnt <= 5'd20 + `SPI_FLASH_DUMMY_CLOCKS; // cmd: 8 clocks  address: 12 clocks  + dummy clocks
      end else begin
	 if(busy) begin
	    shifter <= {shifter[37:0], (receiving ? IO_in : 2'b11)};
	    clock_cnt <= clock_cnt - 5'd1;	    
	    if(dir && clock_cnt == 1) begin
 	       clock_cnt <= 5'd16; // 32 bits, 2 bits per clock
	       IO_oe <= 1'b0;
	       dir   <= 1'b0;
	    end 
	 end else begin
	    CS_N <= 1'b1;
	 end
      end
   end
endmodule
 

/*
// 04/02/2021 This version optimized by Matthias Koch
module MappedSPIFlash(
    input  wire        clk,          // system clock
    input  wire        rstrb,        // read strobe
    input  wire [19:0] word_address, // read address

    output wire [31:0] rdata,        // data read
    output wire        rbusy,        // asserted if busy receiving data

    output wire        CLK,          // clock
    output wire        CS_N,         // chip select negated (active low)
    inout  wire [1:0]  IO            // two bidirectional IO pins
);

   reg [6:0]  clock_cnt; // send/receive clock, 2 bits per clock (dual IO)
   reg [39:0] shifter;   // used for sending and receiving

   wire    busy   = ~clock_cnt[6];
   assign  CS_N   =  clock_cnt[6];
   assign  rbusy  =  busy;
   assign  CLK    =  busy & !clk; // CLK needs to be disabled when not active.

   // Since least significant bytes are read first, we need to swizzle...
   assign rdata={shifter[7:0],shifter[15:8],shifter[23:16],shifter[31:24]};

   // The two data pins IO0 (=MOSI) and IO1 (=MISO) used in bidirectional mode.
   wire [1:0] IO_out = shifter[39:38];
   wire [1:0] IO_in  = IO;
   assign IO = clock_cnt > 7'd15 ? IO_out : 2'bZZ;
// assign IO = |clock_cnt[5:4] ? IO_out : 2'bZZ; // optimized version of the line above

   always @(posedge clk) begin
      if(rstrb) begin
         shifter <= {16'hCFCF, 2'b00, word_address[19:0], 2'b00}; // 16'hCFCF is 8'hbb with bits doubled
         clock_cnt <= 7'd43; // cmd: 8 clocks address: 12 clocks dummy: 8 clocks. data: 16 clocks, 2 bits per clock
      end else begin
         if(busy) begin
            shifter <= {shifter[37:0], IO_in};
            clock_cnt <= clock_cnt - 7'd1;
         end
      end
   end
endmodule
*/

`endif
