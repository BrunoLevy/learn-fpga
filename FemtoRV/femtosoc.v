// Bruno Levy, May 2020, learning Verilog,
//
// Trying to fit a minimalistic RV32I core on an IceStick,
// and trying to organize the source in such a way I can understand
// what I have written a while after...


// Comment-out if running out of LUTs (makes shifter faster, but uses 66 LUTs)
// (inspired by PICORV32). 
`define NRV_TWOSTAGE_SHIFTER

`define NRV_RESET      // It is sometimes good to have a physical reset button, 
                         // this one is active low (wire a push button and a pullup 
                         // resistor to pin 47 or change in nanorv.pcf). 

// Optional mapped IO devices
`define NRV_IO_LEDS   // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_IO_UART_RX   // Mapped IO, virtual UART receiver    (USB)
//`define NRV_IO_UART_TX   // Mapped IO, virtual UART transmetter (USB)
`define NRV_IO_SSD1351 // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX2719 // Mapped IO, 8x8 led matrix

// Uncomment one of them. With UART, only 4K possible, but with OLed screen, 6K fits.
//`define NRV_RAM_4K
//`define NRV_RAM_5K
`define NRV_RAM_6K


`define ADDR_WIDTH 14 // Internal number of bits for PC and address register.
                      // 6kb needs 13 bits, + 1 page for IO -> 14 bits

/*************************************************************************************/
// Makes it easier to detect typos !
`default_nettype none

`include "femtorv32.v"

// Used by the UART, needs to match frequency defined in the PLL, 
// at the end of the file
`define CLKFREQ   60000000
`include "uart.v"


/********************* Nrv RAM *******************************/

// Memory map: 4 pages of 256 32bit words + 1 virtual page for IO
// Memory address: page[2:0] offset[7:0] byte_offset[1:0]
//
// Page 3'b200 is used for memory-mapped IO's, that redirects the
// signals to IOaddress, IOwr, IOrd, IOin, IOout.
//
// There is enough room for additional pages between the 4 pages 
// and mapped IO, and there are still 4 BRAMs that are available,
// but unfortunately I do not have enough remaining LUTs for 
// address decoder logic...

module NrvMemoryInterface(
  input 	    clk,
  input [13:0] 	    address, 
  input [3:0] 	    wrByteMask,
  input 	    rd,
  input [31:0] 	    in,
  output reg [31:0] out,

  output [7:0] 	    IOaddress, // = address[9:2]
  output 	    IOwr,
  output 	    IOrd,
  input [31:0] 	    IOin, 
  output [31:0]     IOout
);

   wire             isIO   = address[13];
   wire [2:0] 	    page   = address[12:10];
   wire [7:0] 	    offset = address[9:2];
   wire [10:0] 	    addr_internal = {3'b000,offset};

   wire 	    wr    = (wrByteMask != 0);
   wire             wrRAM = wr && !isIO;
   wire             rdRAM = 1'b1; // rd && !isIO; 
                                  // (but in fact if we always read, it does not harm..., 
                                  //  and I have not implemented read signal for instr)

`ifdef NRV_RAM_4K   
   reg [31:0] RAM[1023:0];
`endif
`ifdef NRV_RAM_5K   
   reg [31:0] RAM[1279:0];
`endif
`ifdef NRV_RAM_6K   
   reg [31:0] RAM[1535:0];
`endif   
   reg [31:0] out_RAM;

   initial begin
      $readmemh("FIRMWARE/firmware.hex",RAM); // Read the firmware from the generated hex file.
   end

   // The power of YOSYS: it infers SB_RAM40_4K BRAM primitives automatically ! (and recognizes
   // masked writes, amazing ...)
   
   wire [10:0] word_addr = {page,offset};
   always @(posedge clk) begin
      if(wrRAM) begin
	 if(wrByteMask[0]) RAM[word_addr][ 7:0 ] <= in[ 7:0 ];
	 if(wrByteMask[1]) RAM[word_addr][15:8 ] <= in[15:8 ];
	 if(wrByteMask[2]) RAM[word_addr][23:16] <= in[23:16];
	 if(wrByteMask[3]) RAM[word_addr][31:24] <= in[31:24];	 
      end 
      if(rdRAM) begin
	 out_RAM <= RAM[word_addr];
      end
   end

   always @(*) begin
      out = isIO ? IOin : out_RAM;
   end   
   
   assign IOout     = in;
   assign IOwr      = (wr && isIO);
   assign IOrd      = (rd && isIO);
   assign IOaddress = offset;
   
endmodule

/********************* Nrv IO  *******************************/

module NrvIO(
    input 	      clk, 
    input [7:0]       address, 
    input 	      wr,
    output 	      rd,
    input [31:0]      in, 
    output reg [31:0] out,

    // LEDs D1-D4	     
    output reg [3:0]  LEDs,

    // Oled display
    output            SSD1351_DIN, 
    output            SSD1351_CLK, 
    output 	      SSD1351_CS, 
    output reg 	      SSD1351_DC, 
    output reg 	      SSD1351_RST,
    
    // Serial
    input  	      RXD,
    output            TXD,

    // Led matrix
    output            MAX2719_DIN, 
    output            MAX2719_CS, 
    output            MAX2719_CLK 
);

   /***** Memory-mapped ports, all 32 bits, address/4 *******/
   
   localparam LEDs_address         = 0; // (write) LEDs (4 LSBs)
   localparam SSD1351_CNTL_address = 1; // (read/write) Oled display control
   localparam SSD1351_CMD_address  = 2; // (write) Oled display commands (8 bits)
   localparam SSD1351_DAT_address  = 3; // (write) Oled display data (8 bits)
   localparam UART_RX_CNTL_address = 4; // (read) LSB: data ready
   localparam UART_RX_DAT_address  = 5; // (read) received data (8 bits)
   localparam UART_TX_CNTL_address = 6; // (read) LSB: busy
   localparam UART_TX_DAT_address  = 7; // (write) data to be sent (8 bits)
   localparam MAX2719_CNTL_address = 8; // (read) led matrix LSB: busy
   localparam MAX2719_DAT_address  = 9; // (write)led matrix data (16 bits)
    
   
   /********************** SSD1351 **************************/

`ifdef NRV_IO_SSD1351
   initial begin
      SSD1351_DC  = 1'b0;
      SSD1351_RST = 1'b0;
      LEDs        = 4'b0000;
   end
   
   // Currently sent bit, 1-based index
   // (0000 config. corresponds to idle)
   reg      SSD1351_slow_clk; // clk=60MHz, slow_clk=30MHz
   reg[3:0] SSD1351_bitcount = 4'b0000;
   reg[7:0] SSD1351_shifter = 0;
   wire     SSD1351_sending = (SSD1351_bitcount != 0);
   reg      SSD1351_special; // pseudo-instruction, direct control of RST and DC.

   assign SSD1351_DIN = SSD1351_shifter[7];
   assign SSD1351_CLK = SSD1351_sending && !SSD1351_slow_clk;
   assign SSD1351_CS  = SSD1351_special ? 1'b0 : !SSD1351_sending;

   always @(posedge clk) begin
      SSD1351_slow_clk <= ~SSD1351_slow_clk;
   end
`endif 
   
   /********************** UART receiver **************************/

`ifdef NRV_IO_UART_RX
   
   reg serial_valid_latched = 1'b0;
   wire serial_valid;
   wire [7:0] serial_rx_data;
   reg  [7:0] serial_rx_data_latched;
   rxuart rxUART( 
       .clk(clk),
       .resetq(1'b1),       
       .uart_rx(RXD),
       .rd(1'b1),
       .valid(serial_valid),
       .data(serial_rx_data) 
   );

   always @(posedge clk) begin
      if(serial_valid) begin
         serial_rx_data_latched <= serial_rx_data;
	 serial_valid_latched <= 1'b1;
      end
      if(rd && address == UART_RX_DAT_address) begin
         serial_valid_latched <= 1'b0;
      end
   end
   
`endif

   /********************** UART transmitter ***************************/

`ifdef NRV_IO_UART_TX
   
   wire       serial_tx_busy;
   wire       serial_tx_wr;
   uart txUART(
       .clk(clk),
       .uart_tx(TXD),	       
       .resetq(1'b1),
       .uart_busy(serial_tx_busy),
       .uart_wr_i(serial_tx_wr),
       .uart_dat_i(in[7:0])		 
   );

`endif   

   /********************** MAX2719 led matrix driver *******************/
   
`ifdef NRV_IO_MAX2719
   reg [2:0]  MAX2719_divider;
   always @(posedge clk) begin
      MAX2719_divider <= MAX2719_divider + 1;
   end
   // clk=60MHz, slow_clk=60/8 MHz (max = 10 MHz)
   wire       MAX2719_slow_clk = (MAX2719_divider == 3'b000);
   reg[4:0]   MAX2719_bitcount; // 0 means idle
   reg[15:0]  MAX2719_shifter;

   assign MAX2719_DIN  = MAX2719_shifter[15];
   wire MAX2719_sending = |MAX2719_bitcount;
   assign MAX2719_CS  = !MAX2719_sending;
   assign MAX2719_CLK = MAX2719_sending && MAX2719_slow_clk;
`endif   
   
   /********************* Decoder for IO read **************************/
   
   always @(*) begin
      (* parallel_case, full_case *)
      case(address)
`ifdef NRV_IO_LEDS      
	LEDs_address:         out = {28'b0, LEDs};
`endif
`ifdef NRV_IO_SSD1351
	SSD1351_CNTL_address: out = {31'b0, SSD1351_sending};
`endif
`ifdef NRV_IO_UART_RX
	UART_RX_CNTL_address: out = {31'b0, serial_valid_latched}; 
	UART_RX_DAT_address:  out = serial_rx_data_latched;
`endif
`ifdef NRV_IO_UART_TX
	UART_TX_CNTL_address: out = {31'b0, serial_tx_busy}; 	
`endif
`ifdef NRV_IO_MAX2719
	MAX2719_CNTL_address: out = {31'b0, MAX2719_sending};
`endif	
	default: out = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ;
      endcase
   end

   /********************* Multiplexer for IO write *********************/

   always @(posedge clk) begin
      if(wr) begin
	 case(address)
`ifdef NRV_IO_LEDS	   
	   LEDs_address: begin
	      LEDs <= in[3:0];
	      `bench($display("************************** LEDs = %b", in[3:0]));
	      `bench($display(" in = %h  %d  %b  \'%c\'", in, $signed(in),in,in));
	   end
`endif
`ifdef NRV_IO_SSD1351	   
	   SSD1351_CNTL_address: begin
	      { SSD1351_RST, SSD1351_special } <= in[1:0];
	   end
	   SSD1351_CMD_address: begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b0;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
	   SSD1351_DAT_address: begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b1;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
`endif 
`ifdef NRV_IO_MAX2719
	   MAX2719_DAT_address: begin
	      MAX2719_shifter <= in[15:0];
	      MAX2719_bitcount <= 16;
	   end
`endif	   
	 endcase 
      end else begin 
`ifdef NRV_IO_SSD1351	   	 
	 if(SSD1351_sending && !SSD1351_slow_clk) begin
            SSD1351_bitcount <= SSD1351_bitcount - 4'd1;
            SSD1351_shifter <= {SSD1351_shifter[6:0], 1'b0};
	 end
`endif
`ifdef NRV_IO_MAX2719
	 if(MAX2719_sending &&  MAX2719_slow_clk) begin
            MAX2719_bitcount <= MAX2719_bitcount - 5'd1;
            MAX2719_shifter <= {MAX2719_shifter[14:0], 1'b0};
	 end
`endif	   	 	 
      end 
   end

`ifdef NRV_IO_UART_TX
  assign serial_tx_wr = (wr && address == UART_TX_DAT_address);
`endif  
   
endmodule


/********************* Nrv main *******************************/

module femtosoc(
`ifdef NRV_IO_LEDS	      
   output D1,D2,D3,D4,D5,
`endif	      
`ifdef NRV_IO_SSD1351	      
   output oled_DIN, oled_CLK, oled_CS, oled_DC, oled_RST,
`endif
`ifdef NRV_IO_UART_RX	      
   input  RXD,
`endif
`ifdef NRV_IO_UART_TX	      	      
   output TXD,
`endif	      
`ifdef NRV_IO_MAX2719	   
   output ledmtx_DIN, ledmtx_CS, ledmtx_CLK,
`endif
`ifdef NRV_RESET	      
   input  RESET,
`endif	      
   input  pclk
);

  wire  clk;
   
 `ifdef BENCH
   assign clk = pclk;
 `else   
   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      //.DIVF(7'b0110100), .DIVQ(3'b011), // 80 MHz
      //.DIVF(7'b0110001), .DIVQ(3'b011), // 75 MHz
      .DIVF(7'b1001111), .DIVQ(3'b100), // 60 MHz
      //.DIVF(7'b0110100), .DIVQ(3'b100), // 40 MHz
      //.DIVF(7'b1001111), .DIVQ(3'b101), // 30 MHz
      .FILTER_RANGE(3'b001),
   ) pll (
      .REFERENCECLK(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );
 `endif

  // Not 100% sure of what I'm doing here (but
  // at least it seemingly fixed my pb):
  // A little delay for sending the reset
  // signal after startup. Without it the
  // CPU stays stuck, seemingly fetching
  // ramdom instr from BRAM.
  // (picosoc on icebreaker has the same 
  //  waiting loop at startup).
  // Explanation here: (ice40 BRAM reads incorrect values during
  // first cycles).
  // http://svn.clifford.at/handicraft/2017/ice40bramdelay/README 
  reg [6:0] reset_cnt = 0;
  wire     reset = &reset_cnt;
`ifdef NRV_RESET   
  always @(posedge clk,negedge RESET) begin
     if(!RESET) begin
	reset_cnt <= 0;
     end else begin
	reset_cnt <= reset_cnt + !reset;
     end
  end
`else
  always @(posedge clk) begin
     reset_cnt <= reset_cnt + !reset;
  end
`endif   
   

  wire [31:0] address;
  wire        error;
  
  // Memory-mapped IOs 
  wire [31:0] IOin;
  wire [31:0] IOout;
  wire        IOrd;
  wire        IOwr;
  wire [7:0]  IOaddress;
  NrvIO IO(
     .in(IOin),
     .out(IOout),
     .rd(IOrd),
     .wr(IOwr),
     .address(IOaddress),
`ifdef NRV_IO_LEDS	   
     .LEDs({D4,D3,D2,D1}),
`endif
`ifdef NRV_IO_SSD1351	   
     .SSD1351_DIN(oled_DIN),
     .SSD1351_CLK(oled_CLK),
     .SSD1351_CS(oled_CS),
     .SSD1351_DC(oled_DC),
     .SSD1351_RST(oled_RST),
`endif
`ifdef NRV_IO_UART_RX	   
     .RXD(RXD),
`endif
`ifdef NRV_IO_UART_TX	   
     .TXD(TXD),
`endif	   
`ifdef NRV_IO_MAX2719	   
     .MAX2719_DIN(ledmtx_DIN),
     .MAX2719_CS(ledmtx_CS),
     .MAX2719_CLK(ledmtx_CLK),
`endif
     .clk(clk)
  );
   
  wire [31:0] dataIn;
  wire [31:0] dataOut;
  wire        dataRd;
  wire [3:0]  dataWrByteMask;
   
  NrvMemoryInterface Memory(
    .clk(clk),
    .address(address[13:0]),
    .in(dataOut),
    .out(dataIn),
    .rd(dataRd),
    .wrByteMask(dataWrByteMask),
    .IOin(IOout),
    .IOout(IOin),
    .IOrd(IOrd),
    .IOwr(IOwr),
    .IOaddress(IOaddress)	      
  );

  FemtoRV32 processor(
    .clk(clk),			
    .address(address),
    .dataIn(dataIn),
    .dataOut(dataOut),
    .dataRd(dataRd),
    .dataWrByteMask(dataWrByteMask),
    .reset(reset),
    .error(error)
  );
   
`ifdef NRV_IO_LEDS  
     assign D5 = error;
`endif

endmodule


