HDMI
====

![](Images/HDMI.jpg)

_TL;DR_ self-contained easy example for the ULX3S in 640x480 is 
[here](https://github.com/BrunoLevy/learn-fpga/tree/master/Basic/ULX3S/ULX3S_hdmi).
Generic version with different resolutions is 
[here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test_hires.v).
The graphic board for FemtoRV32 is 
[here](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/DEVICES/FGA.v).

Let us try to add a framebuffer device that sends a portion of the RAM
to the HDMI. I know nothing about HDMI, it is very difficult to find a
simple and self-contained design that works well with the ULX3S. There
are several reasons, one of them is that we need to use some specialized
blocks, that may differ from one FPGA to another. 

First thing I found is the [fpga4fun](https://www.fpga4fun.com/HDMI.html)
website. It has a nice explanation and example program (that will need
to be adapted though). We learn there that the HDMI connector has 19
pins, but that we need to generate signals on 8 of them, forming 4
so-called `TMDS differential pairs`. As far as I understand, a
differential pair is a way of sending a digital signal through a wire
at a high frequency. There will be one for red, for green, for blue and
for the clock. 

Then we learn that there will be an off-screen area, just like VGA. In
other words, as far as I understand, HDMI (or DVI) is just working like VGA, with
the difference that all the signals are digital (and serialized) instead
of analog. Then we see the timings for 640x480 RGB 24bpp 60Hz. We see
that we will need a pixel clock at 25MHz. The ULX3S has a clock at
25MHz, we can use it directly, cool ! Then with the offscreen area, the 
total area will be 800x525. We will also generate a hSync and vSync
signal, just like VGA.

Now we need to serialize the red, green and blue signals, but there are
some complications: we learn that the bits need to be scrambled in
some way, and that there will be 2 additional bits per signal
(if you want to know, this is for minimizing the transitions between
0 and 1, and for balancing the number of 0 and 1). For that,
there is a `TMDS_encoder` module. It takes as input the pixel clock,
the 8-bits channel data, two bits of control, and a VDE (Video Display
Enable) signal (that goes zero when we are offscreen). The two bits of
control are set fo 00 for the red and green signals, and to vSync,hSync
for the blue signal. Each `TMDS_encoder` outputs 10 bits of data.

Now we need to serialize the 10-bits wide red,green and blue TMDS
signals. For this we will need a clock that runs at 10*25MHz = 250MHz.
There is a special block to do that.
We also need three 10-bits shift registers, and a signal that goes high
every 10 ticks of the 250MHz clock to copy the 10-bits TMDS signals into
the shift register. _It seems we cannot simply use the initial 25MHz signal
to do that, probably the way it is generated would make it not well
synchronized or something_.

Finally, we need to send the generated red,green,blue serial signals and
the pixel clock _not the signal that goes high every 10 ticks of the
250 MHz clock ??_ through special blocks that correspond to TMDS pairs.

OK, so it is rather clear, to summarize we have:
 1) something like a VGA signal generator, written in portable verilog 
     [here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test.v)
     (using FPGA4fun's one)
 2) TMDS encoder, also written in portable verilog, that take the red, green and blue signals, and encodes them in 10 bits
     [here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/TMDS_encoder.v)
     (using FPGA4fun's one)
 3) a 250 MHz clock, using special primitives
     [here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_clock.v)
     (ECP5-specific, using Lawrie's one)
 4) shift-registers, written in portable verilog
     [here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test.v)
     (using FPGA4fun's one)      
 5) finally, specialized blocs to generate the TMDS pairs from the
    serialized red,green,blue signals and from the pixel clock. It is
    also ECP5-specific. I'm using the `LVCMOS33D` mode for the HDMI
    pins, specified in the `.lpf` file
    [here](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/ulx3s.lpf).
    It does exactly what I need:
    generate the negative pins from the positive ones. When it is
    active, negative pins should not be driven ! 
    
_How I figured out for `LVCMOS33D` ?_ I was very lucky, I blindly
copied `ulx3s.lpf` from Emard's repository [here](https://github.com/emard/ulx3s/blob/master/doc/constraints/ulx3s_v20.lpf)
then tryed my naive design with inverters (that would not have worked anyway BTW),
but I had an assertion failure in NEXPNR: `Assertion failure: pio == "PIOA"`. 
Pasting the message in Google redirected me [here](https://github.com/YosysHQ/nextpnr/issues/544),
that explains the story (drive only `gpdi_dp` and remove `gpdi_dn`,
because `LVCMOS33D` implies a pseudo-differential driver that drives both
sides of the pair.
  
  
For higher resolution, it is possible to use a specialized ECP5
primitive (`ODDRX1F`) that can shift and send two bits per clock (then using a
125MHz clock instead of 250MHz), see Lawrie's code
[here](https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/fake_differential.v).
Without it, I think that my design can work up to 800x600 (but this will require
changing the frequencies, resolution etc...). For higher resolution,
it will require changing the shifter part as follows, as well as
changing the clocks and resolutions of course:
```
   // Counter now counts modulo 5 instead of modulo 10
   reg [4:0] TMDS_mod5=1;
   wire TMDS_shift_load = TMDS_mod5[4];
   always @(posedge clk_TMDS) TMDS_mod5 <= {TMDS_mod5[3:0],TMDS_mod5[4]};
   
   // Shifter now shifts two bits at each clock
   reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
   always @(posedge clk_TMDS) begin
      TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:2];
      TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:2];
      TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:2];
   end
   
   // DDR serializers: they send D0 at the rising edge and D1 at the falling edge
   ODDRX1F ddr_red  (.D0[TMDS_shift_red[0]),   .D1[TMDS_shift_red[1]),   .Q(TMDS_rgb_p[2]), .SCLK(), .RST(1'b0));
   ODDRX1F ddr_green(.D0[TMDS_shift_green[0]), .D1[TMDS_shift_green[1]), .Q(TMDS_rgb_p[1]), .SCLK(), .RST(1'b0));
   ODDRX1F ddr_blue (.D0[TMDS_shift_blue[0]),  .D1[TMDS_shift_blue[1]),  .Q(TMDS_rgb_p[0]), .SCLK(), .RST(1'b0));   

```

- [Complete sources for ULX3S](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test.v)
- [Version with DDR](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test_DDR.v)

Now we are ready to implement arbitrary modes. Timings can be found [here](http://tinyvga.com/vga-timing).

![](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/FOMU/FOMU_VGA/Images/vga_mode.png)

For each mode, you will need to know:
- pixel clock frequency
- `GFX_width`: width in pixels
- `GFX_height`: height in pixels
- horizontal sync: front porch, pulse width and back porch
- vertical sync: front porch, pulse width and back porch

Based on these parameters, you can implement the scanner as follows:
```
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
```


Then, from the 25 MHz clock of the ULX3S, we will need to generate:
- the pixel clock `pixclk`
- the TMDS clock, 5 times as fast as the pixel clock (at each cycles
  of the pixel clock, it serializes 10 bits of TMDS data, using DDR,
  hence 5 times the freq).

It can be done using a PLL. On the ECP5 that equips the ULX3S, the
specialized block is called `EHXPLLL`. There is a `ecppll` command-line 
tool that configures the correct parameters for you. It is used as
follows:

```
$ ecppll -i 25 -o <tmds_clock_freq> -f tmp.v
```
where `<tmds_clock_freq>` corresponds to 5 times the pixel clock. Then
you can edit tmp.v. In addition, you can modify the generated PLL to
make it generate the pixel clock, using the `CLKOS` pin. To do so,
it is configured as follows:
```
 #(
  ...
  .CLKOS_ENABLE("ENABLED"),
  .CLKOS_DIV(5*CLKOP_DIV),
  .CLKOS_CPHASE(CLKOP_CPHASE),
  .CLKOS_FPHASE(CLKOP_FPHASE),
  ...
 ) pll_i(
  ...
  .CLKOS(pixclk),  
  ...
 );
```
It uses the same parameters as `CLKOP`, except the divisor that is 5
times the one of `CLKOP` (hence 5 times slower).

Now we are equipped to implemement different modes, as shown in 
[this file](https://github.com/BrunoLevy/learn-fpga/blob/master/Basic/ULX3S/ULX3S_hdmi/HDMI_test_hires.v).

References
----------
- [fpga4fun](https://www.fpga4fun.com/HDMI.html)
- [Lawrie's HDMI for ULX3S](https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/)
- [UltraEmbedded's core dvi FB](https://github.com/ultraembedded/core_dvi_framebuffer/blob/master/src_v/dvi.v)
- [Silice HDMI walkthrough](https://github.com/sylefeb/Silice/tree/master/projects/hdmi_test)
- [HDMI with audio](https://github.com/hdl-util/hdmi/)
- [HDMI tutorial (solder own socket)](https://purisa.me/blog/hdmi-on-fpga/)
- [HDMI software bigbanging beamracer](https://github.com/Wren6991/picodvi)
- [Project F](https://projectf.io/posts/video-timings-vga-720p-1080p/)