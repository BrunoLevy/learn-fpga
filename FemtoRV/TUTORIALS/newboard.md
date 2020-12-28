How to add support for a new board
==================================

Step 1: gather information from the board's datasheet
-----------------------------------------------------

First, you will need to find the following informations, from the datasheet of the board:

- which FPGA the board is using:
   . familly: ICE40 or ECP5
   . ICE40 variant: hx1k, up5k, ...
   . ECP5 variant: 25k, 85k, um5g-85k (fast version of 85k), ...
   . Package (what the ship looks like): e.g., tq144 for ICE40 (SMC with pins on 4 sides), CABGA381 for ECP5 (ball grid array SMC), ...

- the frequency used by the board (e.g., 12MHz for Ice40 is common)

- FPGA pin numbers _(start with the first two of the list, then add what you need, one device at a time)_:
   . 1 pin for the clock (mandatory)
   . 5 pins for 5 LEDs (optional, but I'd say mandatory, because first thing you'll want to do is a blinker)
   . 2 pins for the serial connection through USB (RXD and TXD), optional, but you will soon want it to test
   . and then pins for the things you will want to plug to the board (led matrix, oled display), for these
     you can chose among the pins wired to the board's connectors (PMOD or other)
   . 4 pins for SPI flash (optional): in FPGA boards, the configuration of the FPGA is often stored in a small
     flash memory of a few megabytes. Since the FPGA configuration takes a few tenth of kilobytes, this leaves
     room for you to store some data or programs. The SPI flash is a small 8-legged SMC, you can talk to it
     through a serial protocol (some form of SPI). You will need to find 4 pins in the datasheet (clock,
     master-in-slave-out, master-out-slave-in and chip select)
   . 4 pins for SD card (optional): some FPGA boards have a SDCard slot. It is also possible to add a PMOD.
     SDCards also use a form of SPI serial protocol, quite similar to what is used for the SPI flash. 

Step 2: write a constraint file
-------------------------------

Then you will need to specify the FPGA pin numbers in a constraint file. For ICE40 constraint files have the `.pcf` extension,
and for ECP5 the `.lpf` extension (and a different syntax !). Start from a constraint file of the same FPGA family as the one
in your board, and modify the pin numbers.

Step 3: the PLL
---------------

The PLL is a specialized block in the FPGA that converts the board's clock to other frequencies. Femtorv32 uses a wrapper
module `femtopll`, in `RTL/DEVICES/femtopll.v`. If you are lucky (that is, if your board uses the same frequency as something
already programed here), then you can probably directly reuse what is written there, by making sure you define the right macro,
else you will need to add your own values here. 

To find the magic values, there are some utilities (fortunately !):
for ICE40 use `icepll -i inputfreq -o outputfreq`, and for ECP5, use
`ecpll -i inoutfreq -o outputfreq -f tmp.v`.

Step 4: `RTL/femtosoc_config.v`
-------------------------------

At the end of the file, add the rule to define ICE40 or ECP5 for your board.

Step 5: `Makefile`
------------------

You will need to add yosys and nextpnr options for your board (at the beginning of the file), as well as `BOARD`,
`BOARD.synth` and `BOARD.prog` targets.

Step 6: community
-----------------

Tell us your story on twitter ! and PRs are welcome !