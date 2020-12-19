// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, May-June 2020
//
// This file: the "System on Chip" that goes with femtorv32.

/*************************************************************************************/

`include "femtosoc_config.v"     // User configuration of processor and SOC.
`include "PROCESSOR/femtorv32.v" // The processor
`include "DEVICES/femtopll.v"    // The PLL (generates clock at NRV_FREQ)
`include "DEVICES/uart.v"        // The UART (serial port over USB)
`include "DEVICES/SSD1351.v"     // The OLED display
`include "DEVICES/SPIFlash.v"    // Read data from the serial flash chip
`include "DEVICES/MAX7219.v"     // 8x8 led matrix driven by a MAX7219 chip
`include "DEVICES/LEDs.v"        // Driver for 4 leds

/********************* Nrv RAM *******************************/

// Memory map:
//   address[21:2] RAM word address (4 Mb max).
//   address[22]   IO page (1-hot)
//   address[23]   (future) SPI page (1-hot)

module NrvMemoryInterface(
  // Interface with processor			  
  input 	    clk,
  input [23:0] 	    address, 
  input [3:0] 	    wrByteMask, 
  input 	    rd, // read strobe
  input [31:0] 	    in, // data to be written
  output reg [31:0] out, // read data
  output wire 	    rdBusy, // asserted if mem or IO is busy reading 
  output wire 	    wrBusy, // asserted if mem or IO is busy writing
			  
  // Interface with mapped IO devices			  
  output [10:0]     IOaddress, // = address[11:2]
  output 	    IOwr, // IO devices write strobe
  output 	    IOrd, // IO devices read strobe
  input [31:0] 	    IOin, // data to be written to IO
  output [31:0]     IOout,// data read from IO
  input             IOrdBusy,
  input             IOwrBusy			  
);

   wire             isIO   = address[22];
   wire [19:0] word_addr   = address[21:2];

   wire 	    wr    = (wrByteMask != 0);
   wire             wrRAM = wr && !isIO;

   reg [31:0] RAM[(`NRV_RAM/4)-1:0];
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
   assign IOaddress = address[12:2];

   assign rdBusy = IOrdBusy;
   assign wrBusy = IOwrBusy;
   
endmodule

/********************* Nrv IO  *******************************/

module NrvIO(

    input [10:0]      address, 
    input 	      wr,
    input 	      rd,
    input [31:0]      in, 
    output reg [31:0] out,
    output wire       rdBusy,
    output wire       wrBusy,	     
	     
`ifdef NRV_IO_LEDS
    // LEDs D1-D4	     
    output reg [3:0]  LEDs,
`endif

`ifdef NRV_IO_SSD1351
    // Oled display
    output 	      SSD1351_DIN, 
    output 	      SSD1351_CLK, 
    output reg 	      SSD1351_CS, 
    output reg 	      SSD1351_DC, 
    output reg 	      SSD1351_RST,
`endif

`ifdef NRV_IO_UART
    // Serial
    input 	      RXD,
    output 	      TXD,
`endif

`ifdef NRV_IO_MAX7219
    // Led matrix
    output 	      MAX7219_DIN, 
    output 	      MAX7219_CS, 
    output 	      MAX7219_CLK,
`endif

`ifdef NRV_IO_SPI_FLASH
    // SPI flash
    output wire       spi_mosi,
    input wire 	      spi_miso,
    output reg 	      spi_cs_n,
    output wire       spi_clk,
`endif

`ifdef NRV_IO_SPI_SDCARD
    // SPI SDCard
    output reg        sd_mosi,
    input wire 	      sd_miso,
    output reg 	      sd_cs_n,
    output reg        sd_clk,
`endif

`ifdef NRV_IO_BUTTONS
    input wire[5:0]   buttons,
`endif

    input 	      clk
);

   /***** Memory-mapped ports, all 32 bits ****************
    * Mapped IO uses "one-hot" addressing, to make decoder
    * simpler (saves a lot of LUTs), as in J1/swapforth,
    * thanks to Matthias Koch(Mecrisp author) for the idea !
    */  
   
   localparam LEDs_bit         = 0; // (write) LEDs (4 LSBs)
   
   localparam SSD1351_CNTL_bit = 1; // (write) Oled display control
   localparam SSD1351_CMD_bit  = 2; // (write) Oled display commands (8 bits)
   localparam SSD1351_DAT_bit  = 3; // (write) Oled display data (8 bits)

   localparam UART_CNTL_bit    = 4; // (read) busy (bit 9), data ready (bit 8)
   localparam UART_DAT_bit     = 5; // (read/write) received data / data to send (8 bits)
   
   localparam MAX7219_DAT_bit  = 7; // (write) led matrix data (16 bits)

   localparam SPI_FLASH_bit    = 8; // (write SPI address (24 bits) read: data (1 byte) 

                                    // This one is a software "bit-banging" interface (TODO: hw support)
   localparam SPI_SDCARD_bit   = 9; // write: bit 0: mosi  bit 1: clk   bit 2: csn
                                    // read:  bit 0: miso

   localparam BUTTONS_bit      = 10; // read: buttons state

   /*********************** LEDs ****************************/

`ifdef NRV_IO_LEDS
   wire [31:0] leds_rdata;
   LEDDriver leds(
      .clk(clk),
      .rstrb(rd),		  
      .wstrb(wr),			
      .sel(address[LEDs_bit]),
      .wdata(in),		  
      .rdata(leds_rdata),
      .LED(LEDs)
   );
`endif
   
   /********************** SSD1351 **************************/

`ifdef NRV_IO_SSD1351
   wire SSD1351_wbusy;
   SSD1351 oled_display(
      .clk(clk),
      .wstrb(wr),			
      .sel_cntl(address[SSD1351_CNTL_bit]),
      .sel_cmd(address[SSD1351_CMD_bit]),
      .sel_dat(address[SSD1351_DAT_bit]),
      .wdata(in),
      .wbusy(SSD1351_wbusy),
      .DIN(SSD1351_DIN),
      .CLK(SSD1351_CLK),
      .CS(SSD1351_CS),
      .DC(SSD1351_DC),
      .RST(SSD1351_RST)
   );
`endif   

   /********************** UART receiver **************************/

`ifdef NRV_IO_UART
   wire [31:0] uart_rdata;
   wire        uart_rbusy;
   wire        uart_wbusy;
   UART uart(
      .clk(clk),
      .rstrb(rd),	     	     
      .wstrb(wr),
      .sel_cntl(address[UART_CNTL_bit]),
      .sel_dat(address[UART_DAT_bit]),
      .wdata(in),
      .wbusy(uart_wbusy),
      .rdata(uart_rdata),
      .rbusy(uart_rbusy),
      .RXD(RXD),
      .TXD(TXD)	     
   );
`endif 
   
   /********************** MAX7219 led matrix driver *******************/
   
`ifdef NRV_IO_MAX7219
   wire max7219_wbusy;
   MAX7219 max7219(
      .clk(clk),
      .wstrb(wr),
      .sel(address[MAX7219_DAT_bit]),
      .wdata(in),
      .wbusy(max7219_wbusy),
      .DIN(MAX7219_DIN),
      .CS(MAX7219_CS),
      .CLK(MAX7219_CLK)		   
   );
`endif   

   /********************* SPI flash reader *****************************/
   
`ifdef NRV_IO_SPI_FLASH
   wire spi_flash_wbusy;
   wire spi_flash_rbusy;
   wire [31:0] spi_flash_rdata;
   SPIFlash spi_flash(
      .clk(clk),
      .rstrb(rd),
      .wstrb(wr),
      .sel(address[SPI_FLASH_bit]),
      .wdata(in),
      .wbusy(spi_flash_wbusy),		      
      .rdata(spi_flash_rdata),
      .rbusy(spi_flash_rbusy),
      .CLK(spi_clk),
      .CS_N(spi_cs_n),
      .MOSI(spi_mosi),
      .MISO(spi_miso)		      
   );
`endif

   /********************* SPI SDCard  *********************************/
   
`ifdef NRV_IO_SPI_SDCARD
   initial sd_clk  = 1'b0;
   initial sd_mosi = 1'b0;
   initial sd_cs_n = 1'b1;
`endif
   

   /********************* Decoder for IO read **************************/

   always @(*) begin
      out = 32'b0
`ifdef NRV_IO_LEDS      
	    | leds_rdata
`endif
`ifdef NRV_IO_UART
	    | uart_rdata
`endif	    
`ifdef NRV_IO_SPI_FLASH
	    | spi_flash_rdata
`endif
`ifdef NRV_IO_SPI_SDCARD
	    | (address[SPI_SDCARD_bit] ? {31'b0, sd_miso} : 32'b0)
`endif
`ifdef NRV_IO_BUTTONS
	    | (address[BUTTONS_bit] ? {27'b0, buttons} : 32'b0)
`endif
	    ;
   end
   
   /********************* Multiplexer for IO write *********************/

   always @(posedge clk) begin
      if(wr) begin
`ifdef NRV_IO_SPI_SDCARD
	   if(address[SPI_SDCARD_bit]) begin
	      sd_mosi <= in[0];
	      sd_clk  <= in[1];
	      sd_cs_n <= in[2];
	   end
`endif	 
      end	 
   end

/************** rdBusy and wrBusy **************************/
   
   assign rdBusy = 0
`ifdef NRV_IO_UART
	| uart_rbusy
`endif
`ifdef NRV_IO_SPI_FLASH
        | spi_flash_rbusy
`endif		   
; 

   assign wrBusy = 0
`ifdef NRV_IO_SSD1351
	| SSD1351_wbusy
`endif
`ifdef NRV_IO_UART
	| uart_wbusy
`endif
`ifdef NRV_IO_MAX7219
	| max7219_wbusy
`endif		   
`ifdef NRV_IO_SPI_FLASH
        | spi_flash_wbusy
`endif		   
; 
   
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
`ifdef NRV_IO_MAX7219	   
   output ledmtx_DIN, ledmtx_CS, ledmtx_CLK,
`endif
`ifdef NRV_IO_SPI_FLASH
   output spi_mosi,
   input  spi_miso,
   output spi_cs_n,
 `ifndef ULX3S	
   // ULX3S has spi clk shared with ESP32, using USRMCLK (below)	
   output spi_clk,
 `endif		
`endif
`ifdef NRV_IO_SPI_SDCARD
   output sd_mosi,
   input  sd_miso,
   output sd_cs_n,
   output sd_clk,
`endif
`ifdef NRV_IO_BUTTONS
   input [5:0] buttons,
`endif
`ifdef ULX3S
   output wifi_en,		
`endif		
   input  RESET,
   input  pclk
);

// Deactivate the ESP32 so that it does not interfere with
// the other devices (especially the SDCard).
`ifdef ULX3S
   assign wifi_en = 1'b0;
`endif		

// On the ULX3S, the CLK pin of the SPI is multiplexed with the ESP32.
// It can be accessed using the USRMCLK primitive of the ECP5
// as follows.   
`ifdef NRV_IO_SPI_FLASH
 `ifdef ULX3S
   wire   spi_clk;
   wire   tristate = 1'b0;
   USRMCLK u1 (.USRMCLKI(spi_clk), .USRMCLKTS(tristate));
 `endif   
`endif
   
  wire  clk;

  femtoPLL #(
    .freq(`NRV_FREQ)	     
  ) pll(
    .pclk(pclk), 
    .clk(clk)
  );
   
  // A little delay for sending the reset
  // signal after startup. 
  // Explanation here: (ice40 BRAM reads incorrect values during
  // first cycles).
  // http://svn.clifford.at/handicraft/2017/ice40bramdelay/README 
  reg [11:0] reset_cnt = 0;
  wire       reset = &reset_cnt;

   
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
  wire [10:0] IOaddress;
  wire        IOrdBusy;
  wire        IOwrBusy;
   
  NrvIO IO(
     .in(IOin),
     .out(IOout),
     .rd(IOrd),
     .wr(IOwr),
     .address(IOaddress),
     .rdBusy(IOrdBusy),
     .wrBusy(IOwrBusy),	   
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
`ifdef NRV_IO_MAX7219	   
     .MAX7219_DIN(ledmtx_DIN),
     .MAX7219_CS(ledmtx_CS),
     .MAX7219_CLK(ledmtx_CLK),
`endif
`ifdef NRV_IO_SPI_FLASH
     .spi_mosi(spi_mosi),
     .spi_miso(spi_miso),
     .spi_cs_n(spi_cs_n),
     .spi_clk(spi_clk),
`endif
`ifdef NRV_IO_SPI_SDCARD
     .sd_mosi(sd_mosi),
     .sd_miso(sd_miso),
     .sd_cs_n(sd_cs_n),
     .sd_clk(sd_clk),
`endif
`ifdef NRV_IO_BUTTONS
     .buttons(buttons),
`endif
     .clk(clk)
  );
   
  wire [31:0] dataIn;
  wire [31:0] dataOut;
  wire        dataRd;
  wire [3:0]  dataWrByteMask;
  wire        mem_rbusy;
  wire        mem_wbusy;
 
   
  NrvMemoryInterface Memory(
    .clk(clk),
    .address(address[23:0]),
    .in(dataOut),
    .out(dataIn),
    .rd(dataRd),
    .wrByteMask(dataWrByteMask),
    .rdBusy(mem_rbusy),
    .wrBusy(mem_wbusy),			    
    .IOin(IOout),
    .IOout(IOin),
    .IOrd(IOrd),
    .IOwr(IOwr),
    .IOaddress(IOaddress),
    .IOrdBusy(IOrdBusy),
    .IOwrBusy(IOwrBusy)
  );

  FemtoRV32 #(
     .ADDR_WIDTH(24),
`ifdef NRV_RV32M
     .RV32M(1)
`else
     .RV32M(0)	      
`endif	      
  ) processor(
    .clk(clk),			
    .mem_addr(address),
    .mem_wdata(dataOut),
    .mem_wmask(dataWrByteMask),
    .mem_rdata(dataIn),
    .mem_rstrb(dataRd),
    .mem_rbusy(mem_rbusy),
    .mem_wbusy(mem_wbusy),	      
    .reset(reset),
    .error(error)
  );
   
`ifdef NRV_IO_LEDS  
     assign D5 = error;
`endif

endmodule
