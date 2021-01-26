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
There are four versions (from slowest to fastest). They are implemented in
[this file](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/DEVICES/MappedSPIFlash.v).

| Version (used command)          | cycles per 32-bits read | Specificity           |
|---------------------------------|-------------------------|-----------------------|
| SPI_FLASH_READ                  | 64 slow (50 MHz)        | Standard              |
| SPI_FLASH_FAST_READ             | 72 fast (100 MHz)       | Uses dummy cycles     |
| SPI_FLASH_FAST_READ_DUAL_OUTPUT | 56 fast                 | Reverts MOSI          |
| SPI_FLASH_FAST_READ_DUAL_IO     | 44 fast                 | Reverts MISO and MOSI |


Step 1: using READ command (`h03`)
==================================

Let us first see the interface of our SPI flash module:

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
```

It will be mapped in the address space of the FemtoRV32, so we need to have
an interface that fits well with femtosoc memory interface. It will
have a clock `clk`, a read strobe `rstrb` that goes high each time
we want to read data, and a `word_address` that contains the address
of the 32 bits words we want to read. It will appear on `rdata` as soon
as `rbusy` goes low. Then we got the pins of the SPI Flash memory. It 
has a clock `CLK`, a chip select `CS_N` (active low), a pin for
data going from the processor to the SPI Flash called `MOSI` (for
Master Out Slave In), and a pin for data going from the SPI Flash
to the processor, called `MISO` (for Master In Slave Out).

Now the SPI protocol is very simple. To read data, one needs to lower
`CS_N`, then send one bit at a time through `MOSI` the read command
`h03`, then the 24-bits address. Then data will appear on `MISO`. Data
is sent and received with the most significant bit first. The raising
edge of `CLK` should be right in the middle of the bits. It is a bit
annoying, normally one would need to shift `CLK` by half a clock. It
is possible to do so using the `DDR` specialized blocks, but then the
design is non-portable (it is different for Ice40 and ECP5 for
instance). However there is a simple solution: we can shift the bits
at the falling edge of `clk` ! Then the design is very simple, there
will be a shifter for the command and address, and another shifter for
the received data. There could be a state machine, but it is not
necessary: if the number of bits to send is non-zero, we are in the
'sending' state. If the number of bits to receive is non-zero, we are
in the 'receiving' state. And we go from the 'sending' to the
'receiving' state right after sending the last bit !

```
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

But there is a strong limitation: using the READ command, speed is
limited to 50MHz. To go faster, we need to use the FASTREAD command.

Step 2: using FASTREAD command (`h0b`)
======================================

For using the FASTREAD command, we need to send 8 "dummy bits" right
after the command and address. These dummy bits are necessary for the
SPI flash to have sufficient time to read the address and prepare the
data. It can be done simply as follows:

```
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h0b, 4'b0001,word_address[17:0], 2'b00};
	 snd_bitcount <= 6'd40; // instead of 32 before
	 ...
```

Step 3: using DUAL INPUT FASTREAD command (`h3b`)
=================================================

Now we can go significantly faster, by reading two bits at a time
instead of one. It can be done by inverting MOSI once the command, 
address and dummy bits are sent. Note that MOSI is now a bidirectional
pin (`inout`). It switches from output to input by writing `Z` to it.
Then the receive shifter shifts two bits at a time, one read from `MISO`
as before, and the other one from `MOSI`:

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
   assign  MOSI_out = sending && cmd_addr[39];

   initial CS_N = 1'b1;
   assign  CLK  = !CS_N && clk; 

   // since least significant bytes are read first, we need to swizzle...
   assign rdata = {rcv_data[7:0],rcv_data[15:8],rcv_data[23:16],rcv_data[31:24]};

   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N <= 1'b0;
	 cmd_addr <= {8'h3b, 4'b0001,word_address[17:0], 2'b00};
	 snd_bitcount <= 6'd40;
      end else begin
	 if(sending) begin
	    if(snd_bitcount == 1) begin
	       rcv_bitcount <= 6'd32;
	    end
	    snd_bitcount <= snd_bitcount - 6'd1;
	    cmd_addr <= {cmd_addr[30:0],1'b0};
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

Step 4: using DUAL IO FASTREAD command (`hbb`)
==============================================

We can go even faster: since we got two pins, why not using both of them
to send the address ? (then we invert them and use both of them to read
the data as before). Well, the names MOSI and MISO can be misleading, so
now we use instead the two-bits bidirectional signal IO. There is a
gotcha: the command is sent only through MOSI, as before (this is
because the chip cannot guess we'll be using both wires *before*
having received the command !). To do that, I am using a single
shifter (I do not want to have a shifter for the command and a shifter
for the address), but I'm duplicating the bits of the command (using 
the bbyyttee function).  


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
	 snd_clock_cnt <= 5'd28; // cmd: 8 clocks  address: 12 clocks  dummy: 8 clocks
      end else begin
	 if(sending) begin
	    if(snd_clock_cnt == 1) begin
	       rcv_clock_cnt <= 5'd16; // 32 bits (= 16 clocks) 
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

Step 5: LUT golfing
===================
This design is quite heavy in terms of LUT usage. It has:
- a 40-bits shifter for sending the command and address
- a 32-bits shifter for receiving the data
- two 5-bits counters for counting the clocks when sending and receiving

We can save many LUTs (50 to 70) by using a single shifter for sending
and receiving, and by using a single counter, with an additional `dir` flip-flop
to keep track of whether we are sending or receiving.

The code in the end is
slightly less legible, but it is really worth it on the IceStick where
every LUT counts.

```
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
   assign  CLK  = !CS_N && clk; // CLK needs to be disabled when not active.

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
   endfunction;  

   always @(negedge clk) begin
      if(rstrb) begin
	 CS_N  <= 1'b0;
	 IO_oe <= 1'b1;
	 dir   <= 1'b1;
	 shifter <= {bbyyttee(8'hbb), 4'b0001, word_address[17:0], 2'b00};
	 clock_cnt <= 5'd28; // cmd: 8 clocks  address: 12 clocks  dummy: 8 clocks
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
```


Step 6: going even faster
=========================
There are three things we can do to go even faster:
- use 4 pins: the chip has a quad IO mode, using 4 bidirectional pins.
  Unfortunately, *these pins are not wired to FPGA pins* on the ICEStick.
  One (skilled person) could solder them...
- use a smaller number of dummy bits: normally they can be configured
  (I tried with no success for now)
- use the XIP mode: the XIP mode does not require to send any command.
  You send the address and get the data directly ! (I tried with no
  success for now)

References
=========

- [IceStick SPI Flash DataSheet](https://media-www.micron.com/-/media/client/global/documents/products/data-sheet/nor-flash/serial-nor/n25q/n25q_32mb_3v_65nm.pdf?rev=27fc6016fc5249adb4bb8f221e72b395)
- [Another DataSheet (easier to read)](https://www.winbond.com/resource-files/w25q128jv%20spi%20revc%2011162016.pdf)
