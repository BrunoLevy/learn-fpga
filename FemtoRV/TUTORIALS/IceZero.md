#Trenz IceZero

With the icestick being typically more like $120 at the moment an Icezero and raspberry pizero2wh may be more attractive but you will need to have access to a soldering iron to make full use of learn-fpga. I think there is potential to get the on board SRAM mapped into FemtoRV32 program space, but haven't tried yet. The TUTORIALS can be done without the need for soldering on a header.


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

Programming tool sources at [https://github.com/njheb/icotools](URL)

You will be interested in making icezprog, icezprog-0x830000 and icezprog-0x1000000

I'm going to ask about getting this fork adpoted but I don't know the best way to integrate my changes.

For development I used an x86 pc running Ubuntu 20.04 for syntesis and a piz2w with header as the host for the icezero. I mounted an nfs share on a third device and accesed it from the x86 box and piz2wh.

I added an environment variable "RASPI_REMOTE_DIR=$(abspath $(FIRMWARE_DIR)../../../mnt/)" to FemtoRv/FIRMWARE/makefile.inc you should put a dir called "mnt" at the same level as "learn-fpga" or change this environment variable accordingly.  

If there is intereset in this tree then it should not be difficult to get it to fit in. I thought it best to leave the hacky raspberry pi icezprog* tools in my own fork for now, location mentioned above.

The TUTORIAL behaves like the ICESTICK in that it has 6k BRAM but the "make ICEZERO" femtosoc.bin targets 14k BRAM which is the maximum available.

Some of the TUTORIAL bauds are down from 1000000 to 115200 as this works without change on the raspberry pi. I belive it would be possible to go faster by changing the boot config.txt in relation to /dev/ttyS0, but I have not tried and I doubt 1000000 would be possible on none usb adapters.

I've tested with waveshare OLED but not the LEDmatrix. Also there are 3 onboard leds rather than 5, see changes for details.

I'm hopeful that the SRAM will be an easy target for another mapped device, but I am a complete novice with FPGA related stuff. So am pausing here to see how this is recieved.
 