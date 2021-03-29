// Displays hypnotic moving circles with the FOMU
// Need to solder five wires to the FOMU (4 pads plus mass)
// See: https://twitter.com/mntmn/status/1281632873448124417
//      https://twitter.com/foone/status/1281740047461396480
//      https://github.com/mntmn/fomu-vga
 
`default_nettype none // Makes it easier to detect typos !

module vga (
   input  clki,     // ->48 Mhz clock input
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
  // Values obtained using:
  // icepll -i 48 -o 25.125
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

   // LED driver
   // Note: the LED driver is more intelligent than I wish, it changes color
   // at the same frequency whatever the bit of frame I'm using, I need to 
   // understand what's going on here (supposed to be a PWM, maybe I should
   // generate pulses of varying length to control intensity of r,g,b...)

   SB_RGBA_DRV led_driver #(
    .CURRENT_MODE("0b1");       // half current mode 
    .RGB0_CURRENT("0b001111");  // Blue - Needs more current.
    .RGB1_CURRENT("0b000011");  // Red
    .RGB2_CURRENT("0b000011");  // Green
   )(
    .CURREN(1'b1),
    .RGBLEDEN(1'b1),
    .RGB0PWM(frame[0]), // red
    .RGB1PWM(frame[1]), // green			   
    .RGB2PWM(frame[2]), // blue  
    .RGB0(rgb0),
    .RGB1(rgb1),
    .RGB2(rgb2)
   );

endmodule
