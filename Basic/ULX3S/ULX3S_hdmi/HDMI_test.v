// Started from: https://www.fpga4fun.com/HDMI.html (c) fpga4fun.com & KNJN LLC 2013
//   Added comments, adapted to ECP5 / ULX3S, made small changes here and there
//
// - Introduced some ideas from Lawrie's code here: https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/
//   See also https://github.com/sylefeb/Silice/tree/master/projects/hdmi_test (also based on Lawrie's code).
// - I'm not using Lawrie's "fake differential" but instead I'm using LVCMOS33D mode for the HDMI pins in ulx3S.lpf,
//  that automatically generates the negative signal from the positive one.
//   See: https://www.gitmemory.com/issue/YosysHQ/nextpnr/544/751511265
//   See also LATTICE ECP5 and ECP5-5G sysI/O Usage Guide / Technical note
// - In Lawrie's "fake differential", there is the ODRX1F trick that makes it possible to operate at half the
//   frequency for the bit clock, may be interesting/necessary to use for res higher than 640x480.
// - I've seen also some ECP5 primitives: OLVDS (A->Z,ZN) and OBCO (I->OT,OC) 
//   that I tried to use with the standard LVCMOS33 mode, without success.

module HDMI_test(
   input pclk,
   output [3:0] gpdi_dp
   // Note: gpdi_dn[3:0] is generated automatically by LVCMOS33D mode in ulx3s.lpf
);

HDMI_gen hdmi_gen(
   .pixclk(pclk),
   .TMDS_rgb_p(gpdi_dp[2:0]),
   .TMDS_clock_p(gpdi_dp[3])
);

endmodule

/*********************************************************************************/
module HDMI_gen(
   input pixclk,                           // 25MHz
   output [2:0] TMDS_rgb_p,   TMDS_rgb_n,  // HDMI pins: RGB
   output       TMDS_clock_p, TMDS_clock_n // HDMI pins: clock
);

/******** Video generation *******************************************************/
// This part is just like a VGA generator
reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
always @(posedge pixclk) DrawArea <= (CounterX<640) && (CounterY<480);

always @(posedge pixclk) CounterX <= (CounterX==799) ? 0 : CounterX+1;
always @(posedge pixclk) if(CounterX==799) CounterY <= (CounterY==524) ? 0 : CounterY+1;

always @(posedge pixclk) hSync <= (CounterX>=656) && (CounterX<752);
always @(posedge pixclk) vSync <= (CounterY>=490) && (CounterY<492);

/******** Draw something *********************************************************/
// Generate 8-bits red,green,blue signals from X and Y coordinates (the "shader")
wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] red, green, blue;

always @(posedge pixclk) begin
   red   <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
   green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
   blue  <= CounterY[7:0] | W | A;
end

/******** RGB TMDS encoding ***************************************************/
// Generate 10-bits TMDS red,green,blue signals. Blue embeds HSync/VSync in its 
// control part.
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

/******** 250 MHz clock *******************************************************/
// This one needs some FPGA-specific specialized blocks (a PLL).
wire clk_TMDS; // The 250 MHz clock used by the serializers.
HDMI_clock hdmi_clock(.clk(pixclk), .hdmi_clk(clk_TMDS));

/******** Shifter *************************************************************/
// Serialize the three 10-bits TMDS red,green,blue signals.

// Modulo-10 counter (note: most code I found uses a counter reset to 0 when
// it reaches 9. For a small modulo, I prefer to have a circular shift-buffer
// with a single 1 that triggers the signal. I think it is  more elegant, and
// more importantly, it works for a higher fmax (450 MHz here).
reg [9:0] TMDS_mod10=1;
wire TMDS_shift_load = TMDS_mod10[9];
always @(posedge clk_TMDS) TMDS_mod10 <= {TMDS_mod10[8:0],TMDS_mod10[9]};

// Every 10 clocks, we get a fresh R,G,B triplet from the TMDS encoders,
// else we shift.
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
always @(posedge clk_TMDS) begin
   TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:1];
   TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:1];
   TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:1];	
end

/******** Output to HDMI *****************************************************/

// There are four differential pairs to generate (red,greeb,blue,clock).
// Each differential pair has a positive part, and a negative part (just
// negated bit). Here are the positive parts:
assign TMDS_rgb_p[2] =  TMDS_shift_red[0];
assign TMDS_rgb_p[1] =  TMDS_shift_green[0];
assign TMDS_rgb_p[0] =  TMDS_shift_blue[0];
assign TMDS_clock_p  =  pixclk;

//   Note: what's below would not work, _p and _n sides
// require exact synchronization that could not be
// guaranteed if written like that. 
//   In fact, the negative side is not wired in the HDMI_test
// module. I'm generating it at the level of the
// output pins using LVCMOS33D pin type in ulx3s.lpf
assign TMDS_rgb_n[2] = !TMDS_shift_red[0];
assign TMDS_rgb_n[1] = !TMDS_shift_green[0];
assign TMDS_rgb_n[0] = !TMDS_shift_blue[0];
assign TMDS_clock_n = !pixclk;

endmodule
