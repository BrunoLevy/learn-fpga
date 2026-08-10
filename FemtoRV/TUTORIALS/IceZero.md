#Trenz IceZero

With the icestick being typically more like $120 at the moment an Icezero and raspberry pizero2wh or pizerowh may be more attractive but you will need to have access to a soldering iron to make full use of learn-fpga. 

I have mapped the SRAM into FemtoRV32 program space, but maximum stable speed is 40MHz. The TUTORIALS can be done without the need for soldering on a header.


The original board:

[https://hackaday.com/2017/02/08/adding-icezero-to-the-raspberry-pi/](URL)


The trenz version of the populated icezero pcb:

[https://blackmesalabs.wordpress.com/2017/07/04/icezero-fpga-hat-for-raspberrypi-servo-example/](URL)

[https://shop.trenz-electronic.de/en/TE0876-02-A-IceZero-with-Lattice-ICE40HX-4-Mbit-external-SRAM-3.05-x-6.5-cm](URL)


I belive I saw somewhere on the trenz site that you can ask for headers to be soldered on when ordering. I don't know the cost or if there is a minimum batch size for that service.

Repository where the .pcf came from for this port of "learn-fpga" to trenz icezero
[https://www.dropbox.com/s/hwhhca1dxey5whh/default_te.tar.gz?dl=0](URL)

I started from Ice4Pi and there are a few mods for that board which work for my hardware but potentially might not work for the earlier Ice4Pi version.

For programming the IceZero from raspberry pi via bit banging I have made a quick and dirty fork of the icotools github repository [https://github.com/thekroko/icotools](URL) which is itself a fork of [https://github.com/cliffordwolf/icotools](URL)

Programming tool sources at [https://github.com/njheb/icotools](URL) now with improved bbiceprog 

You will be interested in making icezprog, icezprog-0x30000 and icezprog-0x1000000

<s>I'm going to ask about getting this fork adpoted but I don't know the best way to integrate my changes</s>.
As there has been no interest in my pull request on github I will maintain my own branch.

For development I used an x86 pc running Ubuntu 24.04 for syntesis and a piz2w with header as the host for the icezero. I mounted an nfs share on a third device and accesed it from the x86 box and piz2wh initially.

I added an environment variable "RASPI_REMOTE_DIR=$(abspath $(FIRMWARE_DIR)../../../mnt/)" to FemtoRv/FIRMWARE/makefile.inc you should put a dir called "mnt" at the same level as "learn-fpga" or change this environment variable accordingly.

If there is intereset in this tree then it should not be difficult to get it to fit in. I thought it best to leave the hacky raspberry pi icezprog* tools in my own fork for now, location mentioned above.

The TUTORIAL behaves like the ICESTICK in that it has 6k BRAM but the "make ICEZERO" femtosoc.bin targets 14k BRAM which is the maximum available.

<s>Some of the TUTORIAL bauds are down from 1000000 to 115200 as this works without change on the raspberry pi. I belive it would be possible to go faster by changing the boot config.txt in relation to /dev/ttyS0, but I have not tried and I doubt 1000000 would be possible on none usb adapters.</s>

I've tested with waveshare OLED and LEDmatrix. Also there are 3 onboard leds rather than 5, see changes for details.


Fresh Notes for Jan2026

Mostly developed on pi5 4MB bookworm. synthesis tools from default apt repo. Discovered problem last minute.
Also AMD64 ubuntu 24.04 LTS default apt repo tools when synthesis bug found with pi5 bookworm.


2 Years ago I wrote this :
"I'm hopeful that the SRAM will be an easy target for another mapped device, but I am a complete novice with FPGA related stuff. So am pausing here to see how this is recieved."

It took a lot longer to get back to the SRAM than I intended.

I've got my trenz code back in my own upstream repository (BRANCH=ICEZERO-2024)
I also incorporated changes from pull request #132 for another ICE40HX8K target with SRAM immediately after my first go at the trenz icezero in my own tree (BRANCH=SYNC-OLIMEX-ICE40HX8K-EVB)

I kept the make name of ICE40HX8K_EVB for the olimex target.
I've not added a BOARDS/run_olimexice8K.sh or made a .pcf for TUTORIALS/FROMBLINKERTORISCV for ICE40HX8K_EVB

The actual SRAM code is in (BRANCH=SNAPSHOT-SRAM-COMPACTGPIO-TRENZ-IZ-OLIMEX-8K-1K) and is up to date with master as of
2026jan20. 

<s>I still need to revisit the programming tools for trenz icezero icezprog-*</s> 

CAUTION:I seem to have blown up my spare trenz icezero by mounting it on a pi5, unless I was really unlucky and it came out of the box broken. I have yet to go back and see if it's just the tx and or rx that are damaged.

I use a piz2W with header and have it setup as a wifi station.

On the pi I copied the terminal command into a script

picocom -b 115200 /dev/ttyS0 --imap lfcrlf,crcrlf --omap delbs,crlf --send-cmd "ascii-xfr -s -l 30 -n"

Either make ICEZERO or
       make ICE40HX8K_EVB

The respective configs are setup for SRAM.

in FIRMWARE/EXAMPLES there is:


sramtest.c

to the serial console


sram_tinyraytracer.c

to the oled, significat speed ups


ST_NICCC_spi_flash_from_SRAM.c

expects scene1.dat to be in flash at the usual address to be copied from grabs half of the sram for some of the scene data not all the copied scene data is displayed, to do the whole demo one would need a 1MB SRAM chip on an icezero which is not the default, but I belive home made icezeros could be equiped that way.


Only quark has been used as the basis for a special case version femtorv32_quark_sram.v so far. I expect my approach to adapting the x6v sram verilog could be improved on for space and speed as I am new to fpga's and verilog.

I have not looked at what is involved with the other processors yet.

I hope this will be of interest.

In case the 32Mhz frequency an anoyance it it not actually needed it was just the clock used by xv6.

I have not tried to get above 45MHz the synthesis output hovers around there and appears to be the limit without
someone more knowledgable visiting the trenz_sram.v

Late news I have seen instability at 45MHz but SRAM seems fine at 40MHz
This is the same maximum clock for ICE40HX8K_EVB (I bought a board to test my port) and got a olimex 1kevb as well.
The ICE40HX1K_EVB is very limited as it has no PLL.

There is a tiny_tapeout PSRAM module test code in this SNAPSHOT but I have only managed to get spi mode working.
PSRAM is in this snaphot in case it is of interest.

There is also a GPIO device which has bitbang spi and bitbang ledmatrix and bitbang i2c master software support to keep the number of LUTS down. The i2c simulates open drain through never driving high which might be a bit risky but I was trying to save gates while keeping flexability.
 
