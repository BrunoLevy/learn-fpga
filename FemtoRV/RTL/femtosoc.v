// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, May-June 2020
//
// This file: the "System on Chip" that goes with femtorv32.

/*************************************************************************************/

`default_nettype none // Makes it easier to detect typos !

`include "femtosoc_config.v"        // User configuration of processor and SOC.

`ifdef NRV_MINIRV32
 `include "PROCESSOR/mini_femtorv32.v" // Minimalistic version of the processor
`else
 `ifdef NRV_MINIRV32_2
  `include "PROCESSOR/utils.v"
  `include "PROCESSOR/femtorv32_single_file.v" // Minimalistic version of the processor
`else
 `include "PROCESSOR/femtorv32.v"            // The processor
`endif
`endif

`include "PLL/femtopll.v"           // The PLL (generates clock at NRV_FREQ)

`include "DEVICES/uart.v"           // The UART (serial port over USB)
`include "DEVICES/SSD1351_1331.v"   // The OLED display
`include "DEVICES/MappedSPIFlash.v" // Idem, but mapped in memory
`include "DEVICES/MAX7219.v"        // 8x8 led matrix driven by a MAX7219 chip
`include "DEVICES/LEDs.v"           // Driver for 4 leds
`include "DEVICES/SDCard.v"         // Driver for SDCard (just for bitbanging for now)
`include "DEVICES/Buttons.v"        // Driver for the buttons
`include "DEVICES/FGA.v"            // Femto Graphic Adapter
`include "DEVICES/HardwareConfig.v" // Constant registers to query hardware config.

/*************************************************************************************/

module femtosoc(
`ifdef NRV_IO_LEDS
 `ifdef FOMU
   output rgb0,rgb1,rgb2,
 `else
   output D1,D2,D3,D4,D5,
 `endif
`endif	      
`ifdef NRV_IO_SSD1351_1331	      
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
   inout spi_mosi, inout spi_miso, output spi_cs_n,
 `ifndef ULX3S	
   output spi_clk, // ULX3S has spi clk shared with ESP32, using USRMCLK (below)	
 `endif		
`endif
`ifdef NRV_IO_SDCARD
   output sd_mosi, input sd_miso, output sd_cs_n, output sd_clk,
`endif
`ifdef NRV_IO_BUTTONS
   `ifdef ICE_FEATHER
      input [3:0] buttons, 
   `else
      input [5:0] buttons,
   `endif		
`endif
`ifdef ULX3S
   output wifi_en,		
`endif		
   input  RESET,
`ifdef FOMU
   output usb_dp, usb_dn, usb_dp_pu, 
`endif
`ifdef NRV_IO_FGA		
   output [3:0] gpdi_dp,
`endif
`ifdef NRV_IO_IRDA
   output irda_TXD,
   input  irda_RXD,
   output irda_SD,		
`endif   		
   input pclk
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

`ifdef FOMU
   // Internal wires for the LEDs, 
   // need to convert to signal for RGB led
   wire D1,D2,D3,D4,D5;
   // On the FOMU, USB pins should be statically driven if not used   
   assign usb_dp    = 1'b0;
   assign usb_dn    = 1'b0;
   assign usb_dp_pu = 1'b0;
`endif

  wire  clk;
   
  femtoPLL #(
    .freq(`NRV_FREQ)	     
  ) pll(
    .pclk(pclk), 
    .clk(clk)
  );

  // A little delay for sending the reset signal after startup.
  // Explanation here: (ice40 BRAM reads incorrect values during
  // first cycles).
  // http://svn.clifford.at/handicraft/2017/ice40bramdelay/README
  // On the ICE40-UP5K, 4096 cycles do not suffice (-> 65536 cycles)
`ifdef ICE_STICK
  reg [11:0] reset_cnt = 0;   
`else   
  reg [15:0] reset_cnt = 0;
`endif   
  wire       reset = &reset_cnt;

/* verilator lint_off WIDTH */   
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
/* verilator lint_on WIDTH */   
   
/***************************************************************************************************
/*
 * Memory and memory interface
 * memory map:
 *   address[21:2] RAM word address (4 Mb max).
 *   address[23:22]   00: RAM
 *                    01: IO page (1-hot)  (starts at 0x400000)
 *                    10: SPI Flash page   (starts at 0x800000)
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
      .word_address(mem_address[21:2]),
      .rdata(mapped_spi_flash_rdata),
      .rbusy(mapped_spi_flash_rbusy),
      .CLK(spi_clk),
      .CS_N(spi_cs_n),
`ifdef SPI_FLASH_FAST_READ_DUAL_IO				   
      .IO({spi_miso,spi_mosi})
`else				   
      .MISO(spi_miso),
      .MOSI(spi_mosi)
`endif				   
   );
`else   
   wire mem_address_is_io  =  mem_address[22];
   wire mem_address_is_ram = !mem_address[22];
`endif
      
   reg  [31:0] io_rdata; 
   wire [31:0] io_wdata = mem_wdata;
   wire        io_rstrb = mem_rstrb && mem_address_is_io;
   wire        io_wstrb = mem_wstrb && mem_address_is_io;
   wire [19:0] io_word_address = mem_address[21:2]; // word offset in io page
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
`ifndef NRV_RUN_FROM_SPI_FLASH  
   initial begin
      $readmemh("FIRMWARE/firmware.hex",RAM); 
   end
`endif

`ifdef NRV_IO_FGA
   wire mem_address_is_vram = mem_address[21];
`else
   parameter mem_address_is_vram = 1'b0;
`endif
   
   // The power of YOSYS: it infers SB_RAM40_4K BRAM primitives automatically ! (and recognizes
   // masked writes, amazing ...)
   /* verilator lint_off WIDTH */
   always @(posedge clk) begin
      if(mem_address_is_ram && !mem_address_is_vram) begin
	 if(mem_wmask[0]) RAM[ram_word_address][ 7:0 ] <= mem_wdata[ 7:0 ];
	 if(mem_wmask[1]) RAM[ram_word_address][15:8 ] <= mem_wdata[15:8 ];
	 if(mem_wmask[2]) RAM[ram_word_address][23:16] <= mem_wdata[23:16];
	 if(mem_wmask[3]) RAM[ram_word_address][31:24] <= mem_wdata[31:24];	 
      end 
      ram_rdata <= RAM[ram_word_address];
   end
   /* verilator lint_on WIDTH */

`ifdef NRV_IO_FGA
   wire [31:0] FGA_rdata;
   FGA graphic_adapter(
      .clk(clk),
      .sel(mem_address_is_ram && mem_address_is_vram), // HERE
      .mem_wmask(mem_wmask),
      .mem_address(mem_address[16:0]),
      .mem_wdata(mem_wdata),
      .pixel_clk(pclk),
      .gpdi_dp(gpdi_dp),

      .io_rstrb(io_rstrb),		  
      .io_wstrb(io_wstrb),			
      .sel_cntl(io_word_address[IO_FGA_CNTL_bit]),
      .sel_dat(io_word_address[IO_FGA_DAT_bit]),
      .rdata(FGA_rdata)		       
   );
`endif   
   
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
 * Three memory-mapped constant registers that make it easy for
 * client code to query installed RAM and configured devices
 * (this one does not use any pin, of course).
 * Uses some LUTs, a bit stupid, but more comfortable, so that
 * I do not need to change the software on the SDCard each time 
 * I test a different hardware configuration.
 */
`ifdef NRV_IO_HARDWARE_CONFIG   
wire [31:0] hwconfig_rdata;
HardwareConfig hwconfig(
   .clk(clk),			
   .sel_memory(io_word_address[IO_HW_CONFIG_RAM_bit]),
   .sel_devices(io_word_address[IO_HW_CONFIG_DEVICES_bit]),
   .sel_cpuinfo(io_word_address[IO_HW_CONFIG_CPUINFO_bit]),			
   .rdata(hwconfig_rdata)			 
);
`endif
   
/*********************** Four LEDs ************************/
`ifdef NRV_IO_LEDS
   wire [31:0] leds_rdata;
   LEDDriver leds(
`ifdef NRV_IO_IRDA
      .irda_TXD(irda_TXD),
      .irda_RXD(irda_RXD),
      .irda_SD(irda_SD),		
`endif		  
      .clk(clk),
      .rstrb(io_rstrb),		  
      .wstrb(io_wstrb),			
      .sel(io_word_address[IO_LEDS_bit]),
      .wdata(io_wdata),		  
      .rdata(leds_rdata),
      .LED({D4,D3,D2,D1})
   );
`endif

/********************** SSD1351/SSD1331 oled display ******/
`ifdef NRV_IO_SSD1351_1331
   wire SSD1351_wbusy;
   SSD1351 oled_display(
      .clk(clk),
      .wstrb(io_wstrb),			
      .sel_cntl(io_word_address[IO_SSD1351_CNTL_bit]),
      .sel_cmd(io_word_address[IO_SSD1351_CMD_bit]),
      .sel_dat(io_word_address[IO_SSD1351_DAT_bit]),
      .sel_dat16(io_word_address[IO_SSD1351_DAT16_bit]),			
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
      .sel_dat(io_word_address[IO_UART_DAT_bit]),
      .sel_cntl(io_word_address[IO_UART_CNTL_bit]),	     
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
      .sel(io_word_address[IO_MAX7219_DAT_bit]),
      .wdata(io_wdata),
      .wbusy(max7219_wbusy),
      .DIN(ledmtx_DIN),
      .CS(ledmtx_CS),
      .CLK(ledmtx_CLK)		   
   );
`endif   
   
/********************* SPI SDCard  *********************************/
/*
 * This one has an output register directly wired to the CLK,MOSI,CS_N
 * and an input register directly wired to MISO. The software driver
 * implements the SPI protocol by bit-banging (see FIRMWARE/LIBFEMTORV32/spi_sd.c).
 * One day I'll replace it with a hardware driver... if I have time !
 * ... a generic SPI driver would be good to have also.
 */
`ifdef NRV_IO_SDCARD
   wire [31:0] sdcard_rdata;
   SDCard sdcard(
      .clk(clk),
      .rstrb(io_rstrb),
      .wstrb(io_wstrb), 
      .sel(io_word_address[IO_SDCARD_bit]),
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
      .sel(io_word_address[IO_BUTTONS_bit]),
      .rdata(buttons_rdata),
      .BUTTONS(buttons)		   
   );
`endif
   
/************** io_rdata, io_rbusy and io_wbusy signals *************/

/*
 * io_rdata is latched. Not mandatory, but probably allow higher freq, to be tested.
 */ 
always @(posedge clk) begin
   io_rdata <= 0
`ifdef NRV_IO_HARDWARE_CONFIG	       
            | hwconfig_rdata
`endif	       
`ifdef NRV_IO_LEDS      
	    | leds_rdata
`endif
`ifdef NRV_IO_UART
	    | uart_rdata
`endif	    
`ifdef NRV_IO_SDCARD
	    | sdcard_rdata
`endif
`ifdef NRV_IO_BUTTONS
	    | buttons_rdata
`endif
`ifdef NRV_IO_FGA
	    | FGA_rdata
`endif
	    ;
end

   // For now, we got no device that has
   // blocking reads (SPI flash blocks on
   // write address and waits for read data).
   assign io_rbusy = 0 ; 

   assign io_wbusy = 0
`ifdef NRV_IO_SSD1351_1331
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

`ifdef NRV_RV32M
   parameter RV32M = 1;   
`else
   parameter RV32M = 0;      
`endif
   
`ifdef NRV_TWOSTAGE_SHIFTER
   parameter TWOSTAGE_SHIFTER = 1;
`else
   parameter TWOSTAGE_SHIFTER = 0;
`endif   

`ifdef NRV_LATCH_ALU
   parameter LATCH_ALU = 1;
`else
   parameter LATCH_ALU = 0;
`endif   
   
  FemtoRV32 #(
     .ADDR_WIDTH(24)
`ifndef NRV_MINIRV32
`ifndef NRV_MINIRV32_2
     ,.RV32M(RV32M)
     ,.TWOSTAGE_SHIFTER(TWOSTAGE_SHIFTER)
     ,.LATCH_ALU(LATCH_ALU)
`endif     
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
 `ifdef FOMU
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),       // half current
        .RGB0_CURRENT("0b000011"),  // 4 mA
        .RGB1_CURRENT("0b000011"),  // 4 mA
        .RGB2_CURRENT("0b000011")   // 4 mA
    ) RGBA_DRIVER (
        .CURREN(1'b1),
        .RGBLEDEN(1'b1),
        .RGB0PWM(D1), 
        .RGB1PWM(D2), 
        .RGB2PWM(D3), 
        .RGB0(rgb0),
        .RGB1(rgb1),
        .RGB2(rgb2)
    );
 `endif
`endif
   
endmodule
