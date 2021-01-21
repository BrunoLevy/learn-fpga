SPI Flash
=========

FPGA boards often have a tiny 8-legged chip used to store the
configuration of the FPGA. It is flash memory, with a few megabytes
of memory, that is accessed through a serial protocol. The configuration 
of the FPGA only takes a few tenth of kilobytes. There is a lot of space
we can use to store our own data, and we can even store code there, and
directly make FemtoRV32 execute it ! On a board such as the IceStick,
that has only 6Kb of RAM available, it is excellent news, because
it makes it possible to run much larger programs, and all the RAM is
available for our data. However there is a price to pay: it is much
slower than the RAM.


Step 1: using READ command (`h03`)
==================================

```
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
   assign     rbusy = !CS_N; 
   
   assign  MOSI  = sending && cmd_addr[31];
   initial CS_N  = 1'b1;
   assign  CLK   = !CS_N && clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};
   
   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h03, 4'b0001,word_address[17:0], 2'b00};
	 snd_bitcount <= 6'd32;
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b0};
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
```

Step 2: using FASTREAD command (`h0b`)
======================================
```
   reg [39:0] cmd_addr;
```

```
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h0b, 4'b0001,word_address[17:0], 2'b00, 8'b00000000};
	 snd_bitcount <= 6'd40;
	 ...
```

Step 3: using DUAL INPUT FASTREAD command (`h3b`)
=================================================
```
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
```

Step 4: using DUAL IO FASTREAD command (`h3b`)
==============================================
```
module MappedSPIFlash(
    input wire 	       clk, // system clock
    input wire 	       rstrb, // read strobe		
    input wire [17:0]  word_address, // offset from 1Mb

		      
    output wire [31:0] rdata, // data read
    output wire        rbusy, // asserted if busy receiving data 

    output wire        CLK, // clock
    output reg 	       CS_N, // chip select negated (active low)		
    inout wire [1:0]   IO    // two bidirectional IO pins
);

   
   reg [4:0]  snd_clock_cnt; // send clock, 2 bits per clock (dual IO)
   reg [39:0] cmd_addr;      // command + address shift register
   reg [4:0]  rcv_clock_cnt; // receive clock, 2 bits per clock (dual IO)
   reg [31:0] rcv_data;      // received data shift register
   wire       sending   = (snd_clock_cnt != 0);
   wire       receiving = (rcv_clock_cnt != 0);
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
   endfunction;
   
   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N  <= 1'b0;
	 IO_oe <= 1'b1;            	 
	 cmd_addr <= {bbyyttee(8'hbb), 4'b0001, word_address[17:0], 2'b00};
	 snd_clock_cnt <= 5'd20;
      end else begin
	 if(sending) begin
	    if(snd_clock_cnt == 1) begin
	       rcv_clock_cnt <= 5'd24; // 32 bits (= 16 clocks) + 8 dummy clocks
	       IO_oe <= 1'b0;            
	    end
	    snd_clock_cnt <= snd_clock_cnt - 5'd1;
	    cmd_addr <= {cmd_addr[37:0],2'b00};
	 end
	 if(receiving) begin
	    rcv_clock_cnt <= rcv_clock_cnt - 5'd1;
	    rcv_data <= {rcv_data[29:0],IO_in};
	 end
	 if(!busy) begin
	    CS_N <= 1'b1;
	 end
      end
   end
endmodule
```

References
=========

- [IceStick SPI Flash DataSheet](https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf?rev=27fc6016fc5249adb4bb8f221e72b395)
- [Another DataSheet (easier to read)](https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf)