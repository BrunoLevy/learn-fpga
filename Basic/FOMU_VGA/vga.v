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

   wire   pixel_clk;

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
     .PLLOUTCORE     (pixel_clk),
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

   reg  [9:0] X, Y;  // current pixel coordinates
   reg hSync, vSync; // horizontal and vertical synchronization
   reg DrawArea;     // asserted if current pixel is in drawing area
   reg [15:0] frame; // frame counter
   
   always @(posedge pixel_clk) begin
      DrawArea <= (X<640) && (Y<480);
      X        <= (X==799) ? 0 : X+1;
      if(X==799) begin
	 if(Y==524) begin
	    Y <= 0;
	    frame <= frame + 1;
	 end else begin
	    Y <= Y+1;
	 end
      end
      hSync <= (X>=656) && (X<752);
      vSync <= (Y>=490) && (Y<492);
   end
   

   wire [1:0] out_color;
   wire signed [9:0] dx = $signed(X) - 320;
   wire signed [9:0] dy = $signed(Y) - 240;
   wire signed [15:0] R2 = dx*dx + dy*dy - $signed(frame << 6);

   assign out_color = DrawArea ? {R2[12],R2[13]} : 2'b00;

   assign user_1 = hSync;
   assign user_2 = vSync;
   assign user_3 = out_color[0];
   assign user_4 = out_color[1];

   // LED driver
   SB_RGBA_DRV #(
    .CURRENT_MODE("0b1"),       // half current mode
    .RGB0_CURRENT("0b001111"),  // Blue - Needs more current.
    .RGB1_CURRENT("0b000011"),  // Red
    .RGB2_CURRENT("0b000011"),  // Green
   ) led_driver(
    .CURREN(1'b1),
    .RGBLEDEN(1'b1),
    .RGB0PWM(frame[3]), // red
    .RGB1PWM(frame[4]), // green			   
    .RGB2PWM(frame[5]), // blue  
    .RGB0(rgb0),
    .RGB1(rgb1),
    .RGB2(rgb2)
   );

endmodule
