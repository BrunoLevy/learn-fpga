HDMI
====

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
(maybe something like stop and parity bits in serial line). For that,
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
 2) TMDS encoder, also written in portable verilog, that take the red, green and blue signals, and encodes them in 10 bits
 3) a 250 MHz clock, using special primitives
 4) shift-registers, written in portable verilog
 5) finally, specialized blocs to generate the TMDS pairs from the
    serialized red,green,blue signals and from the pixel clock.
  
For 1), 2), 4) I got everything that we need, I know how to do it.
For 3) (250 MHz clock) and 5) (specialized blocs to generate TMDS
pairs) I don't know. It seems that the fpga4fun tutorial uses some
special blocs (`DCM_SP` and `BUFG` for the clock, `OBUFDS` for the
output pins), I'm unsure they exist on the ECP5...

Let us take a look at how my friend @sylefeb did
it in Silice:

 - [hdmi clock](https://github.com/sylefeb/Silice/blob/master/projects/common/hdmi_clock.v)
 
 Ooo I see, simply a `EHXPLLL` that we are already using to generate the clock. 
Now a detail, it outputs the _half_ frequency (125 MHz), probably
because the TMDS pairs do something special with raising edges and
falling edges (in the fpga4fun website, they talk about using DDR
outputs). Let us see what's coming next.

 - [differential pairs](https://github.com/sylefeb/Silice/blob/master/projects/common/differential_pair.v)
 
 Yes, @sylefeb uses the `ODDRX1F` special bloc. Well there is still a
mystery: each differential pair takes two *2-bits* inputs (one
positive, one negative), why ? Let us see how he uses them, 
[here](https://github.com/sylefeb/Silice/blob/master/projects/common/hdmi_differential_pairs.v).
  Ohoo, some Verilog syntax that I don't know, what are these pluses
in the bit ranges specifications ? Ok, answer [here](https://stackoverflow.com/questions/18067571/indexing-vectors-and-arrays-with), so: 
 - `[0+:2]` means `[1:0]`, `2+:1` means [2]
 - `[2+:2]` means `[3:2]`, `1+:1` means [1]
 - `[4+:2]` means `[5:4]`, `0+:1` means [0]
 - `[6+:2]` means `[7:6]`, `3+:1` means [3]

_(Sylvain, why on earth did you use this notation ? Seems
super-convoluted to me, but you probably have a good reason)_.


 Ok it is clear (now), `pos` and `neg` contain information for
CCRRGGBB (in that order, C for clock). Let us see how they are
generated. For that we need to read some [Silice code](https://github.com/sylefeb/Silice/blob/master/projects/common/hdmi.ice).
The key is in `algorithm hdmi_ddr_shifter`, it generates `p_outbits` and `n_outbits`. It uses the 125 MHz clock to shift 2 bits at a time,
I think I got it !

References
----------

[Silice HDMI walkthrough](https://github.com/sylefeb/Silice/tree/master/projects/hdmi_test)
