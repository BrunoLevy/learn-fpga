// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, May-June 2020
//
// This file: the "System on Chip" that goes with femtorv32.

/*************************************************************************************/

`include "femtosoc_config.v"        // User configuration of processor and SOC.
`include "PROCESSOR/femtorv32.v"    // The processor
`include "DEVICES/femtopll.v"       // The PLL (generates clock at NRV_FREQ)
`include "DEVICES/HardwareConfig.v" // Constant registers to query hardware config.
`include "DEVICES/uart.v"           // The UART (serial port over USB)
`include "DEVICES/SSD1351.v"        // The OLED display
`include "DEVICES/SPIFlash.v"       // Read data from the serial flash chip
`include "DEVICES/MappedSPIFlash.v" // Idem, but mapped in memory
`include "DEVICES/MAX7219.v"        // 8x8 led matrix driven by a MAX7219 chip
`include "DEVICES/LEDs.v"           // Driver for 4 leds
`include "DEVICES/SDCard.v"         // Driver for SDCard (just for bitbanging for now)
`include "DEVICES/Buttons.v"        // Driver for the buttons

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
`ifdef NRV_SPI_FLASH
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
   
// On the ULX3S, deactivate the ESP32 so that it does not interfere with 
// the other devices (especially the SDCard).
`ifdef ULX3S
   assign wifi_en = 1'b0;
`endif		

// On the ULX3S, the CLK pin of the SPI is multiplexed with the ESP32.
// It can be accessed using the USRMCLK primitive of the ECP5
// as follows.   
`ifdef NRV_SPI_FLASH
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
/*
 * Memory and memory interface
 * memory map:
 *   address[21:2] RAM word address (4 Mb max).
 *   address[22]   IO page  (1-hot)
 *   address[23]   SPI page (1-hot)
 */ 

   // The memory bus.
   wire [31:0] mem_address; // 24 bits are used internally. The two LSBs are ignored (using word addresses)
   wire  [3:0] mem_wmask;   // mem write mask and strobe /write Legal values are 000,0001,0010,0100,1000,0011,1100,1111
   wire [31:0] mem_rdata;   // processor <- (mem and peripherals) 
   wire [31:0] mem_wdata;   // processor -> (mem and peripherals)
   wire        mem_rstrb;   // mem read strobe. Goes high to initiate memory write.
   wire        mem_rbusy;   // processor <- (mem and peripherals). Stays high until a read transfer is finished.
   wire        mem_wbusy;   // processor <- (mem and peripherals). Stays high until a write transfer is finished.

   wire        mem_wstrb = |mem_wmask; // mem write strobe, goes high to initiate memory write (deduced from wmask)

   // IO bus.
`ifdef NRV_MAPPED_SPI_FLASH
   wire mem_address_is_ram       = (mem_address[23:22] == 2'b00);   
   wire mem_address_is_io        = (mem_address[23:22] == 2'b01);
   wire mem_address_is_spi_flash = (mem_address[23:22] == 2'b10);
   wire mapped_spi_flash_rbusy;
   wire [31:0] mapped_spi_flash_rdata;
   MappedSPIFlash mapped_spi_flash(
      .clk(clk),
      .rstrb(mem_rstrb && mem_address_is_spi_flash),
      .word_address(mem_address[19:2]),
      .rdata(mapped_spi_flash_rdata),
      .rbusy(mapped_spi_flash_rbusy),
      .CLK(spi_clk),
      .CS_N(spi_cs_n),
      .MOSI(spi_mosi),
      .MISO(spi_miso)		      
   );
`else   
   wire mem_address_is_io  =  mem_address[22];
   wire mem_address_is_ram = !mem_address[22];
`endif
      
   reg  [31:0] io_rdata; 
   wire [31:0] io_wdata = mem_wdata;
   wire        io_rstrb = mem_rstrb && mem_address_is_io;
   wire        io_wstrb = mem_wstrb && mem_address_is_io;
   wire [10:0] io_word_address = mem_address[12:2]; // word offset in io page
   wire	       io_rbusy; 
   wire        io_wbusy;
   
   assign      mem_rbusy = io_rbusy
`ifdef NRV_MAPPED_SPI_FLASH
    | mapped_spi_flash_rbusy			   
`endif 			   
    ;
   
   assign      mem_wbusy = io_wbusy; 


   
   wire [19:0] ram_word_address = mem_address[21:2];
   reg [31:0] RAM[(`NRV_RAM/4)-1:0];
   reg [31:0] ram_rdata;

   // Initialize the RAM with the generated firmware hex file.
   // The hex file is generated by the bundled elf-2-verilog converter (see TOOLS/FIRMWARE_WORDS_SRC)
   initial begin
      $readmemh("FIRMWARE/firmware.hex",RAM); 
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
`ifdef NRV_MAPPED_SPI_FLASH
   assign mem_rdata = mem_address_is_io  ? io_rdata  : 
		      mem_address_is_ram ? ram_rdata : 
		      mapped_spi_flash_rdata;   
`else   
   assign mem_rdata = mem_address_is_io ? io_rdata : ram_rdata;
`endif   
   
/***************************************************************************************************
/*
 * Memory-mapped IO
 * Mapped IO uses "one-hot" addressing, to make decoder
 * simpler (saves a lot of LUTs), as in J1/swapforth,
 * thanks to Matthias Koch(Mecrisp author) for the idea !
 * The included files contains the symbolic constants that
 * determine which device uses which bit.
 */  

`include "DEVICES/HardwareConfig_bits.v"   

/*
 * Devices are components plugged to the IO memory bus.
 * A few words follow in case you want to write your own devices:
 *
 * Each device has one or several register(s). Each register 
 * can be optionally read or/and written.
 * - Each register is selected by a .sel_xxx signal (where xxx
 *   is the name of the register). With the 1-hot encoding that 
 *   I'm using, .sel_xxx is systematically one of the bits of the 
 *   IO word address (it is also possible to write a real
 *   address decoder, at the expense of eating-up a larger 
 *   number of LUTs).
 * - If the device requites wait cycles for writing and/or reading, 
 *   it can have a .wbusy and/or .rbusy signal(s). All the .wbusy
 *   and .rbusy signals of all the devices are ORed at the end of
 *   this file to form the .io_rbusy and .io_wbusy signals.
 * - If the device has read access, then it has a 32-bits .xxx_rdata
 *   signal, that returns 32'b0 if the device is not selected, or the
 *   read data otherwise. All the .xxx_rdata signals of all the devices
 *   are ORed at the end of this file to form the 32-bits io_rdata signal.
 * - Finally, of course, each device is plugged to some pins of the FPGA,
 *   the corresponding signals are in capital letters. 
 */   


/*********************** Hardware configuration ************/
/*
 * Two memory-mapped constant registers that make it easy for
 * client code to query installed RAM and configured devices
 * (this one does not use any pin, of course).
 */
wire [31:0] hwconfig_rdata;
HardwareConfig hwconfig(
   .clk(clk),			
   .sel_memory(io_word_address[HW_CONFIG_RAM_bit]),
   .sel_devices_freq(io_word_address[HW_CONFIG_DEVICES_FREQ_bit]),
   .rdata(hwconfig_rdata)			 
);
   
/*********************** Four LEDs ************************/
`ifdef NRV_IO_LEDS
   wire [31:0] leds_rdata;
   LEDDriver leds(
      .clk(clk),
      .rstrb(io_rstrb),		  
      .wstrb(io_wstrb),			
      .sel(io_word_address[LEDs_bit]),
      .wdata(io_wdata),		  
      .rdata(leds_rdata),
      .LED({D4,D3,D2,D1})
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
   UART uart(
      .clk(clk),
      .rstrb(io_rstrb),	     	     
      .wstrb(io_wstrb),
      .sel(io_word_address[UART_DAT_bit]),
      .wdata(io_wdata),
      .rdata(uart_rdata),
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
/* 
 * This one only has a .wbusy signal, going high while address is sent
 * and while data is read, then data is latched, and we do not need
 * a .rbusy signal.
 */
`ifdef NRV_IO_SPI_FLASH
   wire spi_flash_wbusy;
   wire [31:0] spi_flash_rdata;
   SPIFlash spi_flash(
      .clk(clk),
      .rstrb(io_rstrb),
      .wstrb(io_wstrb),
      .sel(io_word_address[SPI_FLASH_bit]),
      .wdata(io_wdata),
      .wbusy(spi_flash_wbusy),		      
      .rdata(spi_flash_rdata),
      .CLK(spi_clk),
      .CS_N(spi_cs_n),
      .MOSI(spi_mosi),
      .MISO(spi_miso)		      
   );
`endif

/********************* SPI SDCard  *********************************/
/*
 * This one has an output register directly wired to the CLK,MOSI,CS_N
 * and an input register directly wired to MISO. The software driver
 * implements the SPI protocol by bit-banging (see FIRMWARE/LIBFEMTORV32/spi_sd.c).
 * One day I'll replace it with a hardware driver... if I have time !
 */
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
/*
 * Directly wired to the buttons.
 */
`ifdef NRV_IO_BUTTONS
   wire [31:0] buttons_rdata;
   Buttons buttons_driver(
      .sel(io_word_address[BUTTONS_bit]),
      .rdata(buttons_rdata),
      .BUTTONS(buttons)		   
   );
`endif
   
/************** io_rdata, io_rbusy and io_wbusy signals *************/

/*
 * io_rdata is latched. Not mandatory, but probably allow higher freq, to be tested.
 */ 
always @(posedge clk) begin
   io_rdata <= hwconfig_rdata
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
end

   // For now, we got no device that has
   // blocking reads (SPI flash blocks on
   // write address and waits for read data).
   assign io_rbusy = 0 ; 

   assign io_wbusy = 0
`ifdef NRV_IO_SSD1351
	| SSD1351_wbusy
`endif
`ifdef NRV_IO_MAX7219
	| max7219_wbusy
`endif		   
`ifdef NRV_IO_SPI_FLASH
        | spi_flash_wbusy
`endif		   
; 

/****************************************************************/
/* And last but not least, the processor                        */
   
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
     assign D5 = error;
`endif
   

   
endmodule
