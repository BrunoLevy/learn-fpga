// https://tomverbeure.github.io/video_timings_calculator
// TODO: is there a way of using nicer parameters instead of
//  macros ?

/*******************************************************************

// VGA utilities for IceStick
// Bruno Levy, April 2020

// Video mode: define one of these before including this file
    VGA_MODE_640x480, 
    VGA_MODE_800x600, 
    VGA_MODE_1024x768, 
    VGA_MODE_1920x1200

// VGAScanner: generates all VGA signals, gives x,y coordinates of current pixel
// VGAClock: pre-tuned PLL to generate pixel clock, according to VGA_MODE_WWWxHHH
// Define VGA_CLOCK_OVERRIDE before including this file to disable default value for VGAClock
// Then, to determine the frequency of VGAClock, you can define one of:
    VGA_25_MHZ
    VGA_36_MHZ
    VGA_50_MHZ    
    VGA_65_MHZ
    VGA_75_MHZ    
    VGA_192_MHZ   

 ********************************************************************/

`ifdef VGA_MODE_640x480
`define VGA_WIDTH  640
`define VGA_HEIGHT 480
   `ifndef VGA_CLOCK_OVERRIDE
      `define VGA_25_MHZ
   `endif   
`endif

`ifdef VGA_MODE_800x600
`define VGA_WIDTH       800
`define VGA_HEIGHT      600
   `ifndef VGA_CLOCK_OVERRIDE
      `define VGA_36_MHZ
   `endif   
`endif

`ifdef VGA_MODE_1024x768
`define VGA_WIDTH  1024
`define VGA_HEIGHT 768
   `ifndef VGA_CLOCK_OVERRIDE
      `define VGA_65_MHZ
   `endif   
`endif

`ifdef VGA_MODE_1920x1200
`define VGA_WIDTH  1920
`define VGA_HEIGHT 1200
   `ifndef VGA_CLOCK_OVERRIDE
      `define VGA_192_MHZ
   `endif       
`endif

`define VGA_COORD_BITS 12


/********************************************************************/


module VGAScanner (
   input wire pixel_clk,                // The pixel clock, needs to be adapted to resolution
   input wire[3:0] R_in,                // The pixel to be displayed
   input wire[3:0] G_in,
   input wire[3:0] B_in,
   output wire hsync, vsync,            // To VGA connector: Horizontal and vertical synchronization  
   input wire[3:0] R_out,               // To 4-bits DAC: color
   input wire[3:0] G_out,
   input wire[3:0] B_out,
   output wire [`VGA_COORD_BITS-1:0] x, // Coordinates of the current pixel
   output wire [`VGA_COORD_BITS-1:0] y,
   output wire new_line,                // pulses at the end of each line
   output wire new_frame,               // pulses at the end of each frame
   output wire in_display_zone          // true if currently displaying an active pixel    
);

`ifdef VGA_MODE_640x480
   parameter h_front_porch = 16;
   parameter h_sync_width  = 96;
   parameter h_back_porch  = 48;
   parameter v_front_porch = 11;
   parameter v_sync_width  = 2;
   parameter v_back_porch  = 28;
`endif

`ifdef VGA_MODE_800x600
   parameter h_front_porch = 24;
   parameter h_sync_width  = 72;
   parameter h_back_porch  = 128;
   parameter v_front_porch = 1;
   parameter v_sync_width  = 2;
   parameter v_back_porch  = 22;
`endif

`ifdef VGA_MODE_1024x768
   parameter h_front_porch = 24;
   parameter h_sync_width  = 136;
   parameter h_back_porch  = 160;
   parameter v_front_porch = 3;
   parameter v_sync_width  = 6;
   parameter v_back_porch  = 29;
`endif

`ifdef VGA_MODE_1920x1200
   parameter h_front_porch = 128;
   parameter h_sync_width  = 208;
   parameter h_back_porch  = 336;
   parameter v_front_porch = 1;
   parameter v_sync_width  = 3;
   parameter v_back_porch  = 38;
`endif

   parameter width         = `VGA_WIDTH;
   parameter height        = `VGA_HEIGHT;
   parameter h_blank       = h_front_porch + h_sync_width + h_back_porch;
   parameter h_pixels      = width + h_blank; 
   parameter v_blank       = v_front_porch + v_sync_width + v_back_porch;
   parameter v_lines       = height + v_blank; 
   parameter hbp = h_back_porch + h_sync_width ; // end of horizontal back porch
   parameter hfp = hbp + width;  // beginning of horizontal front porch
   parameter vbp = v_back_porch + v_sync_width ; // end of vertical back porch
   parameter vfp = vbp + height; // beginning of vertical front porch

   // horizontal & vertical counters
   reg [`VGA_COORD_BITS-1:0] hc;
   reg [`VGA_COORD_BITS-1:0] vc;

   assign in_display_zone = (vc >= vbp && vc < vfp && hc >= hbp && hc < hfp);

   // horizontal and vertical counters 
   always @(posedge pixel_clk) begin
      if (hc < h_pixels - 1) begin
          hc <= hc + 1;
      end else begin
	hc <= 0;
	if (vc < v_lines - 1) begin
	   vc <= vc + 1;
	end else begin
	   vc <= 0;
        end
      end	
   end

   // line and frame signals
   assign new_line  = (hc == hfp);
   assign new_frame = (vc == vfp);   // TODO: maybe begin_frame / end_frame, begin_line / end_line signals.

   // horizontal and vertical synchro
   assign hsync = (hc < h_sync_width) ? 0:1;
   assign vsync = (vc < v_sync_width) ? 0:1;

   // current pixel coordinates
   assign x = hc - hbp;
   assign y = vc - vbp;

   // R,G,B signal
   assign R_out = in_display_zone ? R_in : 4'b0000;
   assign G_out = in_display_zone ? G_in : 4'b0000;
   assign B_out = in_display_zone ? B_in : 4'b0000;   
   
endmodule

/********************************************************************/

module VGAFrameCounter(
   clk,
   frame,
   leds
);
  parameter WIDTH=16;
  input wire clk;
  output wire [WIDTH-1:0] frame;
  output wire [3:0] leds;
  
  reg [WIDTH-1:0] cnt;

  always @(posedge clk) begin
     cnt <= cnt+1;
  end

  assign frame = cnt;

  assign leds = {
    (cnt[3:2] == 2'b00),
    (cnt[3:2] == 2'b01),
    (cnt[3:2] == 2'b10),
    (cnt[3:2] == 2'b11)
  };

endmodule

/********************************************************************/

module VGAClock(
   input  wire clk,
   output wire pixel_clk,
   output wire lock
);

`ifdef VGA_25_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0001),
      .DIVF(7'b1000010),
      .DIVQ(3'b100),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_50_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b1000010),
      .DIVQ(3'b100),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_36_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0101111),
      .DIVQ(3'b100),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_65_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b1010110),
      .DIVQ(3'b100),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_72_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0101111),
      .DIVQ(3'b011),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_75_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0110001),
      .DIVQ(3'b011),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_108_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b1000111),
      .DIVQ(3'b011),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

`ifdef VGA_192_MHZ
  SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0111111),
      .DIVQ(3'b010),
      .FILTER_RANGE(3'b001),
  ) pll (
      .REFERENCECLK(clk),
      .PLLOUTCORE(pixel_clk),
      .LOCK(lock),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );
`endif

endmodule

/********************************************************************/

module ScanlineDoubler (
   input  wire w_clk,           // write clock
   input  wire w_e,             // write enable
   input  wire [7:0]   X_in,    // coord of pixel to be written in line back-buffer
   input  wire [11:0]  RGB_in,  // color of pixel to be written in line back-buffer
   
   input  wire r_clk,           // read clock, 25 Mhz (640x480), or 36 Mhz (800x600)
   output wire hsync, vsync,    // Horizontal and vertical synchro
   output wire [11:0] RGB_out,  // RGB signals
   
   output wire new_line,        // pulses at the beginning of each line
   output wire new_frame        // pulses at the beginning of each frame
);

   wire [`VGA_COORD_BITS-1:0] x;
   wire [`VGA_COORD_BITS-1:0] y;
   wire [11:0] RGB;

   wire new_phys_line;

   VGAScanner vga_scanner(
       .pixel_clk(r_clk),
       .R_in(RGB[3:0]),
       .G_in(RGB[7:4]),
       .B_in(RGB[11:8]),
       .hsync(hsync),
       .vsync(vsync),
       .R_out(RGB_out[3:0]),
       .G_out(RGB_out[7:4]),
       .B_out(RGB_out[11:8]),
       .x(x),
       .y(y),
       .new_line(new_phys_line)
   );

   wire [`VGA_COORD_BITS-1:0] X = (x >> 1) + 1 - (`VGA_WIDTH/2-256)/2;    // Recenter
   wire [`VGA_COORD_BITS-1:0] Y = (y >> 1) + 1; //  - (`VGA_HEIGHT/2-256)/2; // Recenter, +1 because write 1 scanline ahead
   
   assign new_line  = (new_phys_line && y[0] == 0);
   assign new_frame = (y == 0);
   
   wire even = (!y[1]);
   wire odd  = y[1]   ;
   wire [15:0] RGB_ram_1;
   wire [15:0] RGB_ram_2;   
   wire [10:0] r_address = {3'b000,(X[7:0]+8'b00000001)}; // Read 1 pixel ahead.
   SB_RAM40_4K #(
       .READ_MODE(0), 
       .WRITE_MODE(0)
   ) line_buffer_1(
       .RADDR(r_address), 
       .RDATA(RGB_ram_1),
       .RE(odd),
       .RCLK(r_clk),
       .RCLKE(1'b1),
       
       .WADDR({3'b000,X_in}),
       .WDATA({4'b0000,RGB_in}),
       .WE(w_e && even),
       .WCLK(w_clk),
       .WCLKE(1'b1),
   );

   SB_RAM40_4K #(
       .READ_MODE(0), 
       .WRITE_MODE(0)
   ) line_buffer_2(
       .RADDR(r_address),
       .RDATA(RGB_ram_2),
       .RE(even),
       .RCLK(r_clk),
       .RCLKE(1'b1),
       
       .WADDR({3'b000,X_in}),
       .WDATA({4'b0000,RGB_in}),
       .WE(w_e && odd),
       .WCLK(w_clk),
       .WCLKE(1'b1),
   );

    parameter bkg_color = 12'b010000000000;
    wire off_limits = (X == 0 || Y < 3 || X > 255 || Y > 255); // Still unclear to me, some row/columns f*cked up, to be fixed.
    assign RGB = off_limits ? bkg_color : odd ? RGB_ram_1[11:0] : RGB_ram_2[11:0];
    // I would have thought using this one instead, but RE(1'b0) does not ensure that read 
    //  data is zero, so I need one more MUX.
    // assign RGB = off_limits ? bkg_color : (RGB_ram_1[11:0] | RGB_ram_2[11:0]);

endmodule

/********************************************************************/
