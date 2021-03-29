 
`default_nettype none // Makes it easier to detect typos !

  module vga (
                input clki,      // ->48 Mhz clock input
                output rgb0,     // \
                output rgb1,     //  >LED
                output rgb2,     // /
                output user_1,   // ->hsync
                output user_2,   // ->vsync
                output user_3,   // ->color0
                output user_4,   // ->color1
                output usb_dp,   // \
                output usb_dn,   //  >USB pins (should be driven low if not used)
                output usb_dp_pu // /
  );

  // USB pins driven low
  assign usb_dp=0;
  assign usb_dn=0;
  assign usb_dp_pu=0;

  wire pixclk;

  // PLL: converts system clock (48 MHz) 
  // to pixel clock (25.125 MHz for 640x480)
  SB_PLL40_CORE #(
     .FEEDBACK_PATH("SIMPLE"),
     .DIVR(4'b0011),
     .DIVF(7'b1000010),
     .DIVQ(3'b101),
     .FILTER_RANGE(3'b001),
  ) pll (
     .REFERENCECLK   (clki),
     .PLLOUTCORE     (pixclk),
     .BYPASS         (1'b0),
     .RESETB         (1'b1)
  );
  

   // video structure constants
   parameter width         = 640;
   parameter height        = 480;
   parameter h_front_porch = 16;
   parameter h_sync_width  = 96;
   parameter h_back_porch  = 48;
   parameter v_front_porch = 11;
   parameter v_sync_width  = 2;
   parameter v_back_porch  = 28;

   // --------------------------------------------------------------------
   parameter h_blank       = h_front_porch + h_sync_width + h_back_porch;
   parameter h_pixels      = width + h_blank; 
   parameter v_blank       = v_front_porch + v_sync_width + v_back_porch;
   parameter v_lines       = height + v_blank; 
   parameter hbp = h_back_porch + h_sync_width ; // end of horizontal back porch
   parameter hfp = hbp + width;  // beginning of horizontal front porch
   parameter vbp = v_back_porch + v_sync_width ; // end of vertical back porch
   parameter vfp = vbp + height; // beginning of vertical front porch
   // -------------------------------------------------------------------- 

   // horizontal & vertical counters
   reg [9:0] hc;
   reg [9:0] vc;

   wire in_display_zone = (vc >= vbp && vc < vfp && hc >= hbp && hc < hfp);

   // frame counter
   reg [15:0] frame;

   // horizontal and vertical counters 
   always @(posedge pixclk)
   begin
      if (hc < h_pixels - 1) begin
          hc <= hc + 1;
      end else begin
	hc <= 0;
	if (vc < v_lines - 1) begin
	   vc <= vc + 1;
	end else begin
	   frame <= frame + 1;
	   vc <= 0;
        end
      end	
   end

   // horizontal and vertical synchro
   wire hsync = (hc < h_sync_width) ? 0:1;
   wire vsync = (vc < v_sync_width) ? 0:1;

   // X,Y coordinates of current pixel
   wire [9:0] X = hc - hbp;
   wire [9:0] Y = vc - vbp;

   wire [1:0] out_color;

   wire signed [9:0] dx = $signed(X) - 320;
   wire signed [9:0] dy = $signed(Y) - 240;
   wire signed [15:0] R2 = dx*dx + dy*dy - $signed(frame << 6);

   assign out_color = in_display_zone ? {R2[12],R2[13]} : 2'b00;

   assign user_1 = hsync;
   assign user_2 = vsync;
   assign user_3 = out_color[0];
   assign user_4 = out_color[1];


  // Instantiate iCE40 LED driver hard logic, connecting up
  // latched button state, counter state, and LEDs.
  //
  // Note that it's possible to drive the LEDs directly,
  // however that is not current-limited and results in
  // overvolting the red LED.
  //
  // See also:
  // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668
  
  SB_RGBA_DRV RGBA_DRIVER (
                           .CURREN(1'b1),
                           .RGBLEDEN(1'b1),
                           .RGB0PWM(frame[5]), // red
                           .RGB1PWM(frame[6]), // green			   
                           .RGB2PWM(frame[7]), // blue  
                           .RGB0(rgb0),
                           .RGB1(rgb1),
                           .RGB2(rgb2)
  );

  // Parameters from iCE40 UltraPlus LED Driver Usage Guide, pages 19-20
  localparam RGBA_CURRENT_MODE_FULL = "0b0";
  localparam RGBA_CURRENT_MODE_HALF = "0b1";

  // Current levels in Full / Half mode
  localparam RGBA_CURRENT_04MA_02MA = "0b000001";
  localparam RGBA_CURRENT_08MA_04MA = "0b000011";
  localparam RGBA_CURRENT_12MA_06MA = "0b000111";
  localparam RGBA_CURRENT_16MA_08MA = "0b001111";
  localparam RGBA_CURRENT_20MA_10MA = "0b011111";
  localparam RGBA_CURRENT_24MA_12MA = "0b111111";

  // Set parameters of RGBA_DRIVER (output current)
  //
  // Mapping of RGBn to LED colours determined experimentally
  defparam RGBA_DRIVER.CURRENT_MODE = RGBA_CURRENT_MODE_HALF;
  defparam RGBA_DRIVER.RGB0_CURRENT = RGBA_CURRENT_16MA_08MA;  // Blue - Needs more current.
  defparam RGBA_DRIVER.RGB1_CURRENT = RGBA_CURRENT_08MA_04MA;  // Red
  defparam RGBA_DRIVER.RGB2_CURRENT = RGBA_CURRENT_08MA_04MA;  // Green

endmodule
