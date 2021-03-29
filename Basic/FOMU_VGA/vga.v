
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

  assign usb_dp=0;
  assign usb_dn=0;
  assign usb_dp_pu=0;
  
  wire hs;
  wire vs;
  reg pixel;

  wire [31:0] dist = (counter_x - 320)*(counter_x - 320) + (counter_y - 200) * (counter_y - 200) - (counter << 8);

  reg [31:0] counter;

  assign user_1 = hs;
  assign user_2 = vs;
  assign user_3 = dist[15]; // pixel;
  assign user_4 = dist[14]; // 0;

  SB_PLL40_CORE #(
                  .FEEDBACK_PATH("SIMPLE"),
                  .DIVR(4'b0010),
                  .DIVF(7'b0100111),
                  .DIVQ(3'b100),
                  .FILTER_RANGE(3'b001),
                  ) uut (
                         .REFERENCECLK   (clki),
                         .PLLOUTCORE     (pixclk),
                         .BYPASS         (1'b0),
                         .RESETB         (1'b1)
                  );

  // Use counter logic to divide system clock.  The clock is 48 MHz,
  // so we divide it down by 2^28.
  reg [10:0] counter_x = 0;
  reg [10:0] counter_y = 0;

  // 800 840 968 1056 600 601 605 628 @ 40MHz
  
  localparam HS_START = 16;
  localparam HS_END = 16+(968-840);
  localparam H_TOTAL = 1056;
  
  localparam VS_START = 601;
  localparam VS_END = 605;
  localparam V_TOTAL = 628;
  
  assign hs = ~((counter_x >= HS_START) & (counter_x < HS_END));
  assign vs = ~((counter_y >= VS_START) & (counter_y < VS_END));

  always @(posedge vs) begin
     counter <= counter + 1;
  end

  always @(posedge pixclk) begin
    if (counter_x < H_TOTAL)
      counter_x <= counter_x + 1;
    else begin
      counter_x <= 0;
      if (counter_y < V_TOTAL)
        counter_y <= counter_y + 1;
      else
        counter_y <= 0;
    end

    if (counter_x>300 && counter_x<400 && counter_y>200 && counter_y<300)
      pixel = 1;
    else
      pixel = 0;
  end

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
                           .RGB0PWM(counter[8]), // red
                           .RGB1PWM(counter[9]), // green			   
                           .RGB2PWM(counter[10]), // blue  
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
