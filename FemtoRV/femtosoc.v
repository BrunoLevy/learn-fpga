// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, May-June 2020
//
// This file: the "System on Chip" that goes with femtorv32.
//
// Note: the UART eats up many LUTs, to activate it you need to
//  deactivate NRV_TWOSTAGE_SHIFTER

// Comment-out if running out of LUTs (makes shifter faster, but uses 60-100 LUTs)
// (inspired by PICORV32). 
`define NRV_TWOSTAGE_SHIFTER

`define NRV_NEGATIVE_RESET // Uncomment if the RESET button is wired and active low:
                           // (wire a push button and a pullup resistor to 
                           // pin 47 or change in nanorv.pcf). 

`define NRV_COMPACT_PREDICATES // Uncomment to try experimental code to gain
`define NRV_COMPACT_ALU        // some LUTs (note: depending on YOSYS version,
                               // results in fewer LUTs, or more LUTs sometimes !)


// On the ECP5 evaluation board, there is already a wired button, active low,
// wired to the "P4" ball of the ECP5 (see femtosoc.lpf)
`ifdef ECP5
 `ifndef NRV_NEGATIVE_RESET
  `define NRV_NEGATIVE_RESET
 `endif
`endif


// Optional mapped IO devices
`define NRV_IO_LEDS    // Mapped IO, LEDs D1,D2,D3,D4 (D5 is used to display errors)
//`define NRV_IO_UART    // Mapped IO, virtual UART (USB)
`define NRV_IO_SSD1351 // Mapped IO, 128x128x64K OLed screen
//`define NRV_IO_MAX2719 // Mapped IO, 8x8 led matrix
`define NRV_IO_SPI_FLASH  // Mapped IO, SPI flash  

// Uncomment one of them. Using smaller RAM saves a few LUTs (for address decoding),
// depending on configured resources and YOSYS / Nextpnr versions, you may need them !
// IMPORTANT: make sure declared quantity of RAM in FIRMWARE/LIB/crt0.s matches !!!

//`define NRV_RAM_4K
//`define NRV_RAM_5K
`define NRV_RAM_6K

`define ADDR_WIDTH 16 // Internal number of bits for PC and address register.
                      // 6kb needs at least 13 bits, + 1 page for IO -> 14 bits.
                      // Seems that 16 bits uses a *smaller* number of LUTs
                      // (and leaves additional space for future extensions).

/*************************************************************************************/
// Makes it easier to detect typos !
`default_nettype none

// Toggle FPGA defines (ICE40, ECP5) in function of board defines (ICE_STICK, ECP5_EVN)
// Board defines are set in compilation scripts (makeit_icestick.sh and makeit_ecp5_evn.sh)

`ifdef ICE_STICK
 `define ICE40
`endif

`ifdef ECP5_EVN
 `define ECP5 
`endif

`include "femtorv32.v"
`include "femtopll.v"

// Used by the UART, needs to match frequency defined in the PLL, 
// at the end of the file
// Seems that 80 MHz can work (note: code for peripherals such
// as OLED screen and SPI ram needs to be adapted if > 60MHz)
// Default is 60 MHz.

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

  output [8:0] 	    IOaddress, // = address[10:2]
  output 	    IOwr,
  output 	    IOrd,
  input [31:0] 	    IOin, 
  output [31:0]     IOout
);

   wire             isIO   = address[13];
   wire [10:0] word_addr   = address[12:2];


   wire 	    wr    = (wrByteMask != 0);
   wire             wrRAM = wr && !isIO;

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
   always @(posedge clk) begin
      if(wrRAM) begin
	 if(wrByteMask[0]) RAM[word_addr][ 7:0 ] <= in[ 7:0 ];
	 if(wrByteMask[1]) RAM[word_addr][15:8 ] <= in[15:8 ];
	 if(wrByteMask[2]) RAM[word_addr][23:16] <= in[23:16];
	 if(wrByteMask[3]) RAM[word_addr][31:24] <= in[31:24];	 
      end 
      out_RAM <= RAM[word_addr];
   end

   always @(*) begin
      out = isIO ? IOin : out_RAM;
   end   
   
   assign IOout     = in;
   assign IOwr      = (wr && isIO);
   assign IOrd      = (rd && isIO);
   assign IOaddress = address[10:2];
   
endmodule

/********************* Nrv IO  *******************************/

module NrvIO(

    input [8:0]       address, 
    input 	      wr,
    input 	      rd,
    input [31:0]      in, 
    output reg [31:0] out,

`ifdef NRV_IO_LEDS
    // LEDs D1-D4	     
    output reg [3:0]  LEDs,
`endif

`ifdef NRV_IO_SSD1351
    // Oled display
    output            SSD1351_DIN, 
    output            SSD1351_CLK, 
    output 	      SSD1351_CS, 
    output reg 	      SSD1351_DC, 
    output reg 	      SSD1351_RST,
`endif

`ifdef NRV_IO_UART
    // Serial
    input  	      RXD,
    output            TXD,
`endif

`ifdef NRV_IO_MAX2719
    // Led matrix
    output            MAX2719_DIN, 
    output            MAX2719_CS, 
    output            MAX2719_CLK,
`endif

`ifdef NRV_IO_SPI_FLASH
    // SPI flash
    output wire spi_mosi,
    input  wire spi_miso,
    output reg  spi_cs_n,
    output wire spi_clk,
`endif

    input clk
);

   /***** Memory-mapped ports, all 32 bits ****************
    * Mapped IO uses "one-hot" addressing, to make decoder
    * simpler (saves a lot of LUTs), as in J1/swapforth,
    * thanks to Matthias (Mecrisp author) for the idea !
    */  
   
   localparam LEDs_bit         = 0; // (write) LEDs (4 LSBs)
   localparam SSD1351_CNTL_bit = 1; // (read/write) Oled display control
   localparam SSD1351_CMD_bit  = 2; // (write) Oled display commands (8 bits)
   localparam SSD1351_DAT_bit  = 3; // (write) Oled display data (8 bits)


   localparam UART_CNTL_bit    = 4; // (read) busy (bit 9), data ready (bit 8)
   localparam UART_DAT_bit     = 5; // (read/write) received data / data to send (8 bits)
   
   localparam MAX2719_CNTL_bit = 6; // (read) led matrix LSB: busy
   localparam MAX2719_DAT_bit  = 7; // (write)led matrix data (16 bits)

   localparam SPI_FLASH_bit    = 8; // (write SPI address (24 bits) read: data (1 byte) + rdy (bit 8)

   /********************** SSD1351 **************************/

`ifdef NRV_IO_LEDS
   initial begin
      LEDs = 4'b0000;
   end
`endif   

`ifdef NRV_IO_SSD1351
   initial begin
      SSD1351_DC  = 1'b0;
      SSD1351_RST = 1'b0;
   end

   // Currently sent bit, 1-based index
   // (0000 config. corresponds to idle)
   reg      SSD1351_slow_clk; // clk=60MHz, slow_clk=30MHz
   
   reg[3:0] SSD1351_bitcount = 4'b0000;
   reg[7:0] SSD1351_shifter = 0;
   wire     SSD1351_sending = (SSD1351_bitcount != 0);
   reg      SSD1351_special; // pseudo-instruction, direct control of RST and DC.

   assign SSD1351_DIN = SSD1351_shifter[7];

   // Normally SSD1351_sending should not be tested here, it should work with
   // SSD1351_CLK = SSD1351_slow_clk, but without testing SSD1351_sending,
   // test_OLED.s, test_OLED.c and mandelbrot_OLED.s do not work, whereas the
   // other C OLED demos work (why ? To be understood...) 
   assign SSD1351_CLK = SSD1351_sending &&  SSD1351_slow_clk; 
   assign SSD1351_CS  = SSD1351_special ? 1'b0 : !SSD1351_sending;

   always @(posedge clk) begin
      SSD1351_slow_clk <= ~SSD1351_slow_clk;
   end
`endif 
   
   /********************** UART receiver **************************/

`ifdef NRV_IO_UART
   
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
      if(rd && address[UART_DAT_bit]) begin
         serial_valid_latched <= 1'b0;
      end
   end
   
`endif

   /********************** UART transmitter ***************************/

`ifdef NRV_IO_UART
   
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

   /********************* SPI flash reader *****************************/
   
`ifdef NRV_IO_SPI_FLASH
   reg [5:0]  spi_flash_snd_bitcount;
   reg [31:0] spi_flash_cmd_addr;
   reg [3:0]  spi_flash_rcv_bitcount;
   reg [7:0]  spi_flash_dat;
   wire       spi_flash_sending   = (spi_flash_snd_bitcount != 0);
   wire       spi_flash_receiving = (spi_flash_rcv_bitcount != 0);
   wire       spi_flash_busy = spi_flash_sending | spi_flash_receiving;
   reg 	spi_flash_slow_clk; // clk=60MHz, slow_clk=30MHz

   assign  spi_mosi = spi_flash_sending && spi_flash_cmd_addr[31];
   initial spi_cs_n = 1'b1;
   assign  spi_clk  = spi_flash_busy && spi_flash_slow_clk;
   
   always @(posedge clk) begin
      spi_flash_slow_clk <= ~spi_flash_slow_clk;
   end
`endif


   /********************* Decoder for IO read **************************/

   always @(*) begin
      out = 32'b0
`ifdef NRV_IO_LEDS      
	    | (address[LEDs_bit] ? {28'b0, LEDs} : 32'b0) 
`endif
`ifdef NRV_IO_SSD1351
	    | (address[SSD1351_CNTL_bit] ? {31'b0, SSD1351_sending} : 32'b0)
`endif
`ifdef NRV_IO_UART
	    | (address[UART_CNTL_bit]? {22'b0, serial_tx_busy, serial_valid_latched, 8'b0} : 32'b0) 
	    | (address[UART_DAT_bit] ? serial_rx_data_latched : 32'b0)	      

`endif	    
`ifdef NRV_IO_MAX2719
	    | (address[MAX2719_CNTL_bit] ? {31'b0, MAX2719_sending} : 32'b0)
`endif	
`ifdef NRV_IO_SPI_FLASH
	    | (address[SPI_FLASH_bit] ? {23'b0, spi_flash_busy, spi_flash_dat} : 32'b0)
`endif
	    ;
   end
   
   /********************* Multiplexer for IO write *********************/

   always @(posedge clk) begin
      if(wr) begin
`ifdef NRV_IO_LEDS	   
	   if(address[LEDs_bit]) begin
	      LEDs <= in[3:0];
	      `bench($display("************************** LEDs = %b", in[3:0]));
	      `bench($display(" in = %h  %d  %b  \'%c\'", in, $signed(in),in,in));
	   end
`endif
`ifdef NRV_IO_SSD1351	   
	   if(address[SSD1351_CNTL_bit]) begin
	      { SSD1351_RST, SSD1351_special } <= in[1:0];
	   end
	   if(address[SSD1351_CMD_bit]) begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b0;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
	   if(address[SSD1351_DAT_bit]) begin
	      SSD1351_special <= 1'b0;
	      SSD1351_RST <= 1'b1;
	      SSD1351_DC <= 1'b1;
	      SSD1351_shifter <= in[7:0];
	      SSD1351_bitcount <= 8;
	   end
`endif 
`ifdef NRV_IO_MAX2719
	   if(address[MAX2719_DAT_bit]) begin
	      MAX2719_shifter <= in[15:0];
	      MAX2719_bitcount <= 16;
	   end
`endif
`ifdef NRV_IO_SPI_FLASH
	   if(address[SPI_FLASH_bit]) begin
	      spi_cs_n <= 1'b0;
	      spi_flash_cmd_addr <= {8'h03, in[23:0]};
	      spi_flash_snd_bitcount <= 6'd32;
	   end
`endif	 
      end else begin
`ifdef NRV_IO_SSD1351
	 if(SSD1351_sending && SSD1351_slow_clk) begin
            SSD1351_bitcount <= SSD1351_bitcount - 4'd1;
            SSD1351_shifter <= {SSD1351_shifter[6:0], 1'b0};
	 end
`endif
`ifdef NRV_IO_SPI_FLASH
	 if(spi_flash_sending && spi_flash_slow_clk) begin
	    if(spi_flash_snd_bitcount == 1) begin
	       spi_flash_rcv_bitcount <= 4'd8;
	    end
	    spi_flash_snd_bitcount <= spi_flash_snd_bitcount - 6'd1;
	    spi_flash_cmd_addr <= {spi_flash_cmd_addr[30:0],1'b0};
	 end
	 if(spi_flash_receiving && spi_flash_slow_clk) begin
	    spi_flash_rcv_bitcount <= spi_flash_rcv_bitcount - 4'd1;
	    spi_flash_dat <= {spi_flash_dat[6:0],spi_miso};
	 end
	 if(!spi_flash_busy && spi_flash_slow_clk) begin
	    spi_cs_n <= 1'b1;
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

`ifdef NRV_IO_UART
  assign serial_tx_wr = (wr && address[UART_DAT_bit]);
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
`ifdef NRV_IO_UART	      
   input  RXD,
   output TXD,
`endif	      
`ifdef NRV_IO_MAX2719	   
   output ledmtx_DIN, ledmtx_CS, ledmtx_CLK,
`endif
`ifdef NRV_IO_SPI_FLASH
   output spi_mosi,
   input  spi_miso,
   output spi_cs_n,
   output spi_clk,
`endif
   input  RESET,
   input  pclk
);

  wire  clk;

  femtoPLL pll(.pclk(pclk), .clk(clk));
   
  // A little delay for sending the reset
  // signal after startup. 
  // Explanation here: (ice40 BRAM reads incorrect values during
  // first cycles).
  // http://svn.clifford.at/handicraft/2017/ice40bramdelay/README 
  reg [7:0] reset_cnt = 0;
  wire     reset = &reset_cnt;
   
`ifdef NRV_NEGATIVE_RESET
   always @(posedge clk,negedge RESET) begin
      if(!RESET) begin
	 reset_cnt <= 0;
      end else begin
	 reset_cnt <= reset_cnt + !reset;
      end
   end
`else
   always @(posedge clk,posedge RESET) begin
      if(RESET) begin
	 reset_cnt <= 0;
      end else begin
	 reset_cnt <= reset_cnt + !reset;
      end
   end
`endif

  wire [31:0] address;
  wire        error;
  
  // Memory-mapped IOs 
  wire [31:0] IOin;
  wire [31:0] IOout;
  wire        IOrd;
  wire        IOwr;
  wire [8:0]  IOaddress;
  
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
`ifdef NRV_IO_UART	   
     .RXD(RXD),
     .TXD(TXD),
`endif	   
`ifdef NRV_IO_MAX2719	   
     .MAX2719_DIN(ledmtx_DIN),
     .MAX2719_CS(ledmtx_CS),
     .MAX2719_CLK(ledmtx_CLK),
`endif
`ifdef NRV_IO_SPI_FLASH
     .spi_mosi(spi_mosi),
     .spi_miso(spi_miso),
     .spi_cs_n(spi_cs_n),
     .spi_clk(spi_clk),
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


