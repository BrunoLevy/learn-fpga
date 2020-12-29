How to add support for a new board
==================================

Step 1: gather information from the board's datasheet
-----------------------------------------------------

First, you will need to find the following informations, from the datasheet of the board:

- which FPGA the board is using:
   - familly: ICE40 or ECP5
   - ICE40 variant: hx1k, up5k, ...
   - ECP5 variant: 25k, 85k, um5g-85k (fast version of 85k), ...
   - Package (what the ship looks like): e.g., tq144 for ICE40 (SMC with pins on 4 sides), CABGA381 for ECP5 (ball grid array SMC), ...

- the frequency used by the board (e.g., 12MHz for the IceStick ...)

- FPGA pin numbers _(start with the first two of the list, then add what you need, one device at a time)_:
   - 1 pin for the clock (mandatory)
   - 5 pins for 5 LEDs (optional, but I'd say mandatory, because first thing you'll want to do is a blinker)
   - 2 pins for the serial connection through USB (RXD and TXD), optional, but you will soon want it to test
   - and then pins for the things you will want to plug to the board (led matrix, oled display), for these
     you can chose among the pins wired to the board's connectors (PMOD or other)
   - 4 pins for SPI flash (optional): in FPGA boards, the configuration of the FPGA is often stored in a small
     flash memory of a few megabytes. Since the FPGA configuration takes a few tenth of kilobytes, this leaves
     room for you to store some data or programs. The SPI flash is a small 8-legged SMC, you can talk to it
     through a serial protocol (some form of SPI). You will need to find 4 pins in the datasheet (clock,
     master-in-slave-out, master-out-slave-in and chip select)
   - 4 pins for SD card (optional): some FPGA boards have a SDCard slot. It is also possible to add a PMOD.
     SDCards also use a form of SPI serial protocol, quite similar to what is used for the SPI flash. 

Step 2: write a constraint file
-------------------------------

Then you will need to specify the FPGA pin numbers in a constraint
file. For ICE40 constraint files have the `.pcf` extension, and for
ECP5 the `.lpf` extension (and a different syntax !). The constraints
file are in the `BOARDS` subdirectory. Start from a constraint file of
the same FPGA family as the one in your board, and modify the pin
numbers.

Step 3: the PLL
---------------

The PLL is a specialized block in the FPGA that converts the board's
clock to other frequencies. Femtorv32 uses a wrapper module
`femtopll`, in `RTL/PLL/femtopll.v`, that redirects to board-dependent
implementatons in `RTL/PLL/pll_xxx.v`.

The first thing you may do is starting from the board's native
frequency, by defining `PASSTHROUGH_PLL` in
`RTL/femtosoc_config.v`. This directly wires the board's clock `pclk`
to the processor clock `clk` in `RTL/femtosoc.v`. You will also need
to define `NRV_FREQ` as the board's frequency (the UART used for
serial communication at 115200 bauds depends on it). If the board's
clock is too fast, then you may divide it using a counter (see
e.g. `RTL/PLL/pll_fomu.v`).

Then, once this works, you'll probably want to use a true PLL instead,
because it lets you fine-tune the frequency.  Start by copying the one
that most resembles your board. To find the magic values, there are
some utilities (fortunately !): for ICE40 use `icepll -i inputfreq -o
outputfreq`, and for ECP5, use `ecpll -i inoutfreq -o outputfreq -f
tmp.v`.  There is even better: I wrote a script that does it
automatically for you: ``` $ cd RTL/PLL $ ./gen_pll.sh FPGA_type
board_freq > pll_boardname.pll ``` where `FPGA_type` is `ICE40` or
`ECP5`, and where `board_freq` is the native frequency of the
board. It will generate all magic values for you ! Then you need to
edit `femtopll.v` and add a statement to include your new file.

Note for ICE-40: you may need to edit the generated file, and replace
`SB_PLL40_CORE` with `SB_PLL40_PAD` and `.REFERENCECLK` with
`.PACKAGEPIN`. More explanations about that are given
[here](https://github.com/mystorm-org/BlackIce-II/wiki/PLLs-Improved)



Step 4: `RTL/femtosoc_config.v`
-------------------------------

At the end of the file, add the rule to define ICE40 or ECP5 for your board.

Step 5: `Makefile`
------------------

You will need to create a new `BOARDS/board.mk`, with yosys and
nextpnr options for your board, as well as `BOARD`, `BOARD.synth` 
and `BOARD.prog` targets. Start by copying the one that is mostly
similar to yours and adapt it.

Step 6: community
-----------------

Tell us your story on twitter ! and PRs are welcome !