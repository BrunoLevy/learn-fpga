`default_nettype none // Makes it easier to detect typos !

/*********************************************************************************/
module HDMI_test_hires(
   input pclk,          // 25MHz
   output [3:0] gpdi_dp // 0: blue 1: green 2: red 3: pixel clock
                        // gpdi_dn[3:0] generated automatically 
			// using IO_TYPE=LVCMOS33D in ulx3s.lpf 
			// (D=Differential)
);

/******** Video mode constants and clocks ****************************************/

wire pixclk;        // pixel clock
wire half_clk_TMDS; // TMDS clock at half freq (5*pixclk)

// Select mode by uncommenting one of the lines below
`define MODE_640x480
//`define MODE_1024x768
//`define MODE_1280x1024

`ifdef MODE_640x480

   // 640x480, pixclk=25 MHz
   localparam GFX_width         = 640;
   localparam GFX_height        = 480;
   localparam GFX_h_front_porch = 16;
   localparam GFX_h_sync_width  = 96;
   localparam GFX_h_back_porch  = 48;
   localparam GFX_v_front_porch = 10;
   localparam GFX_v_sync_width  = 2;
   localparam GFX_v_back_porch  = 32;
   
   // Parameters of the PLL, found using: ecppll -i 25 -o 125 -f foobar.v
   localparam CLKI_DIV = 1;
   localparam CLKOP_DIV = 5;
   localparam CLKOP_CPHASE = 2;
   localparam CLKOP_FPHASE = 0;
   localparam CLKFB_DIV = 5;

`endif

`ifdef MODE_1024x768
   // 1024x768, pixel clock=65Mhz
   localparam GFX_width         = 1024;
   localparam GFX_height        = 768;
   localparam GFX_h_front_porch = 24;
   localparam GFX_h_sync_width  = 136;
   localparam GFX_h_back_porch  = 160;
   localparam GFX_v_front_porch = 3;
   localparam GFX_v_sync_width  = 6;
   localparam GFX_v_back_porch  = 29;

   // Parameters of the PLL, found using: ecppll -i 25 -o 325 -f foobar.v
   localparam CLKI_DIV = 1;
   localparam CLKOP_DIV = 2;
   localparam CLKOP_CPHASE = 1;
   localparam CLKOP_FPHASE = 0;
   localparam CLKFB_DIV = 13;
`endif

`ifdef MODE_1280x1024

   // 1280x1024, pixel clock=108MHz
   localparam GFX_width         = 1280;
   localparam GFX_height        = 1024;
   localparam GFX_h_front_porch = 48;
   localparam GFX_h_sync_width  = 112;
   localparam GFX_h_back_porch  = 248;
   localparam GFX_v_front_porch = 1;
   localparam GFX_v_sync_width  = 3;
   localparam GFX_v_back_porch  = 38;

   // Parameters of the PLL, found using: ecppll -i 25 -o 540 -f foobar.v
   localparam CLKI_DIV = 3;
   localparam CLKOP_DIV = 1;
   localparam CLKOP_CPHASE = 0;
   localparam CLKOP_FPHASE = 0;
   localparam CLKFB_DIV = 65;
`endif

/******** The PLL ************************************************************/

   // The PLL converts a 25 MHz clock into a (pixel_clock_freq * 5) clock
   // The TMDS serializers operate at (pixel_clock_freq * 10), but we use
   // DDR mode, hence (pixel_clock_freq * 5).
   // The (half) TMDS serializer clock is generated on pin CLKOP. 
   // In addition, the pixel clock (at TMDS freq/5) is generated on 
   // pin CLKOS (hence CLKOS_DIV = 5*CLKOP_DIV).
   (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .CLKI_DIV(CLKI_DIV),
        .CLKOP_DIV(CLKOP_DIV),
        .CLKOP_CPHASE(CLKOP_CPHASE),
        .CLKOP_FPHASE(CLKOP_FPHASE),
	.CLKOS_ENABLE("ENABLED"),
	.CLKOS_DIV(5*CLKOP_DIV),
	.CLKOS_CPHASE(CLKOP_CPHASE),
	.CLKOS_FPHASE(CLKOP_FPHASE),
        .CLKFB_DIV(CLKFB_DIV)
    ) pll_i (
        .CLKI(pclk),
        .CLKOP(half_clk_TMDS),
        .CLKFB(half_clk_TMDS),
	.CLKOS(pixclk),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0)
     );

/******** X,Y,hSync,vSync,DrawArea ***********************************************/

localparam GFX_line_width = GFX_width  + GFX_h_front_porch + GFX_h_sync_width + GFX_h_back_porch;
localparam GFX_lines      = GFX_height + GFX_v_front_porch + GFX_v_sync_width + GFX_v_back_porch;

reg [10:0] GFX_X, GFX_Y;
reg hSync, vSync, DrawArea;

always @(posedge pixclk) DrawArea <= (GFX_X<GFX_width) && (GFX_Y<GFX_height);

always @(posedge pixclk) GFX_X <= (GFX_X==GFX_line_width-1) ? 0 : GFX_X+1;
always @(posedge pixclk) if(GFX_X==GFX_line_width-1) GFX_Y <= (GFX_Y==GFX_lines-1) ? 0 : GFX_Y+1;

always @(posedge pixclk) hSync <= 
   (GFX_X>=GFX_width+GFX_h_front_porch) && (GFX_X<GFX_width+GFX_h_front_porch+GFX_h_sync_width);
   
always @(posedge pixclk) vSync <= 
   (GFX_Y>=GFX_height+GFX_v_front_porch) && (GFX_Y<GFX_height+GFX_v_front_porch+GFX_v_sync_width);

/******** Draw something *********************************************************/

// Generate 8-bits red,green,blue signals from X and Y coordinates (the "shader")
wire [7:0] W = {8{GFX_X[7:0]==GFX_Y[7:0]}};
wire [7:0] A = {8{GFX_X[7:5]==3'h2 && GFX_Y[7:5]==3'h2}};
reg [7:0] red, green, blue;

always @(posedge pixclk) begin
   red   <= ({GFX_X[5:0] & {6{GFX_Y[4:3]==~GFX_X[4:3]}}, 2'b00} | W) & ~A;
   green <= (GFX_X[7:0] & {8{GFX_Y[6]}} | W) & ~A;
   blue  <= GFX_Y[7:0] | W | A;
end

/******** RGB TMDS encoding ***************************************************/
// Generate 10-bits TMDS red,green,blue signals. Blue embeds HSync/VSync in its 
// control part.
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

/******** Shifter *************************************************************/
// Serialize the three 10-bits TMDS red,green,blue signals.
// This version of the shifter shifts and sends two bits per clock,
// using the ODDRX1F block of the ULX3S.
   
// The counter counts modulo 5 instead of modulo 10 (because we shift two
// bits at each clock)
reg [4:0] TMDS_mod5=1;
always @(posedge half_clk_TMDS) TMDS_mod5 <= {TMDS_mod5[3:0],TMDS_mod5[4]};
wire TMDS_shift_load = TMDS_mod5[4];

// Shifter now shifts two bits at each clock
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
always @(posedge half_clk_TMDS) begin
   TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:2];
   TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:2];
   TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:2];
end
   
// DDR serializers: they send D0 at the rising edge and D1 at the falling edge.
ODDRX1F ddr_red  (.D0(TMDS_shift_red[0]),   .D1(TMDS_shift_red[1]),   .Q(gpdi_dp[2]), .SCLK(half_clk_TMDS), .RST(1'b0));
ODDRX1F ddr_green(.D0(TMDS_shift_green[0]), .D1(TMDS_shift_green[1]), .Q(gpdi_dp[1]), .SCLK(half_clk_TMDS), .RST(1'b0));
ODDRX1F ddr_blue (.D0(TMDS_shift_blue[0]),  .D1(TMDS_shift_blue[1]),  .Q(gpdi_dp[0]), .SCLK(half_clk_TMDS), .RST(1'b0));
   
// The pixel clock is sent through the fourth differential pair.
assign gpdi_dp[3] = pixclk;

// Note (again): gpdi_dn[3:0] is generated automatically by LVCMOS33D mode in ulx3s.lpf

endmodule
