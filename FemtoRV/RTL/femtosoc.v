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
`include "DEVICES/SDCard.v"      // Driver for SDCard (just for bitbanging for now)
`include "DEVICES/Buttons.v"     // Driver for the buttons

/*************************************************************************************/

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
   output spi_mosi, input spi_miso, output spi_cs_n,
 `ifndef ULX3S	
   output spi_clk, // ULX3S has spi clk shared with ESP32, using USRMCLK (below)	
 `endif		
`endif
`ifdef NRV_IO_SPI_SDCARD
   output sd_mosi, input sd_miso, output sd_cs_n, output sd_clk,
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

/********************* Technicalities **************************************/
   
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

/***************************************************************************************************
 * Memory and memory interface
 * memory map:
 *   address[21:2] RAM word address (4 Mb max).
 *   address[22]   IO page (1-hot)
 *   address[23]   (future) SPI page (1-hot)
 */ 

   // The memory bus
   wire [31:0] mem_address;
   wire  [3:0] mem_wmask;
   wire [31:0] mem_rdata;
   wire [31:0] mem_wdata;   
   wire        mem_rstrb;
   wire        mem_rbusy;
   wire        mem_wbusy;

   wire        mem_wstrb = |mem_wmask;
   
   // IO bus. All addresses are word offsets in IO page.
   wire        mem_address_is_io = mem_address[22];
   wire [31:0] io_rdata;
   wire [31:0] io_wdata = mem_wdata;
   wire        io_rstrb = mem_rstrb && mem_address_is_io;
   wire        io_wstrb = mem_wstrb && mem_address_is_io;
   wire [10:0] io_word_address = mem_address[12:2];
   wire        io_rbusy;
   wire        io_wbusy;
   assign      mem_rbusy = io_rbusy;
   assign      mem_wbusy = io_wbusy;

   wire        mem_address_is_ram = !mem_address[22];
   wire [19:0] ram_word_address = mem_address[21:2];
   reg [31:0] RAM[(`NRV_RAM/4)-1:0];
   reg [31:0] ram_rdata;

   initial begin
      $readmemh("FIRMWARE/firmware.hex",RAM); // Read the firmware from the generated hex file.
   end

   // The power of YOSYS: it infers SB_RAM40_4K BRAM primitives automatically ! (and recognizes
   // masked writes, amazing ...)
   always @(posedge clk) begin
      if(mem_address_is_ram) begin
	 if(mem_wmask[0]) RAM[ram_word_address][ 7:0 ] <= mem_wdata[ 7:0 ];
	 if(mem_wmask[1]) RAM[ram_word_address][15:8 ] <= mem_wdata[15:8 ];
	 if(mem_wmask[2]) RAM[ram_word_address][23:16] <= mem_wdata[23:16];
	 if(mem_wmask[3]) RAM[ram_word_address][31:24] <= mem_wdata[31:24];	 
      end 
      ram_rdata <= RAM[ram_word_address];
   end
   assign mem_rdata = mem_address_is_io ? io_rdata : ram_rdata;
   
   
/***************************************************************************************************
 * Memory-mapped IO
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

   
/*********************** 4 LEDs ****************************/
`ifdef NRV_IO_LEDS
   wire [31:0] leds_rdata;
   LEDDriver leds(
      .clk(clk),
      .rstrb(io_rstrb),		  
      .wstrb(io_wstrb),			
      .sel(io_word_address[LEDs_bit]),
      .wdata(io_wdata),		  
      .rdata(leds_rdata),
      .LED({D5,D4,D3,D2})
   );
`endif

/********************** SSD1351 oled display ************************/   
`ifdef NRV_IO_SSD1351
   wire SSD1351_wbusy;
   SSD1351 oled_display(
      .clk(clk),
      .wstrb(io_wstrb),			
      .sel_cntl(io_word_address[SSD1351_CNTL_bit]),
      .sel_cmd(io_word_address[SSD1351_CMD_bit]),
      .sel_dat(io_word_address[SSD1351_DAT_bit]),
      .wdata(io_wdata),
      .wbusy(SSD1351_wbusy),
      .DIN(oled_DIN),
      .CLK(oled_CLK),
      .CS(oled_CS),
      .DC(oled_DC),
      .RST(oled_RST)
   );
`endif   

/********************** UART ****************************************/
`ifdef NRV_IO_UART
   wire [31:0] uart_rdata;
   wire        uart_rbusy;
   wire        uart_wbusy;
   UART uart(
      .clk(clk),
      .rstrb(io_rstrb),	     	     
      .wstrb(io_wstrb),
      .sel_cntl(io_word_address[UART_CNTL_bit]),
      .sel_dat(io_word_address[UART_DAT_bit]),
      .wdata(io_wdata),
      .wbusy(uart_wbusy),
      .rdata(uart_rdata),
      .rbusy(uart_rbusy),
      .RXD(RXD),
      .TXD(TXD)	     
   );
`endif 

/********** MAX7219 led matrix driver *******************************/
`ifdef NRV_IO_MAX7219
   wire max7219_wbusy;
   MAX7219 max7219(
      .clk(clk),
      .wstrb(io_wstrb),
      .sel(io_word_address[MAX7219_DAT_bit]),
      .wdata(io_wdata),
      .wbusy(max7219_wbusy),
      .DIN(ledmtx_DIN),
      .CS(ledmtx_CS),
      .CLK(ledmtx_CLK)		   
   );
`endif   
   
/********************* SPI flash reader *****************************/
`ifdef NRV_IO_SPI_FLASH
   wire spi_flash_wbusy;
   wire spi_flash_rbusy;
   wire [31:0] spi_flash_rdata;
   SPIFlash spi_flash(
      .clk(clk),
      .rstrb(io_rstrb),
      .wstrb(io_wstrb),
      .sel(address[SPI_FLASH_bit]),
      .wdata(io_wdate),
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
   wire [31:0] sdcard_rdata;
   SDCard sdcard(
      .clk(clk),
      .rstrb(io_rstrb),
      .wstrb(io_wstrb), 
      .sel(io_word_address[SPI_SDCARD_bit]),
      .wdata(io_wdata),
      .rdata(sdcard_rdata),
      .CLK(sd_clk),
      .MISO(sd_miso),		 
      .MOSI(sd_mosi),
      .CS_N(sd_cs_n)
   );
`endif

/********************* Buttons  *************************************/
`ifdef NRV_IO_BUTTONS
   wire [31:0] buttons_rdata;
   Buttons buttons_driver(
      .sel(io_word_address[BUTTONS_bit]),
      .rdata(buttons_rdata),
      .BUTTONS(buttons)		   
   );
`endif
   
/************** io_rdata, io_rbusy and io_wbusy signals *************/

   assign io_rdata = 32'b0
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
	    | sdcard_rdata
`endif
`ifdef NRV_IO_BUTTONS
	    | buttons_rdata
`endif
	    ;
   
   assign io_rbusy = 0
`ifdef NRV_IO_UART
	| uart_rbusy
`endif
`ifdef NRV_IO_SPI_FLASH
        | spi_flash_rbusy
`endif		   
; 

   assign io_wbusy = 0
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

/****************************************************************/

  wire error;
   
  FemtoRV32 #(
     .ADDR_WIDTH(24),
`ifdef NRV_RV32M
     .RV32M(1)
`else
     .RV32M(0)	      
`endif	      
  ) processor(
    .clk(clk),			
    .mem_addr(mem_address),
    .mem_wdata(mem_wdata),
    .mem_wmask(mem_wmask),
    .mem_rdata(mem_rdata),
    .mem_rstrb(mem_rstrb),
    .mem_rbusy(mem_rbusy),
    .mem_wbusy(mem_wbusy),	      
    .reset(reset),
    .error(error)
  );
   
`ifdef NRV_IO_LEDS  
     assign D1 = error;
`endif
   

   
endmodule
