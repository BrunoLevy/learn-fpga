Installing open-source tools for FPGA development
=================================================

_Note: the following instructions are for Linux (I'm using Ubuntu).
Windows users can run the tutorial using WSL. It requires some
adaptation, as explained [here](WSL.md)._

Before starting, you will need to install the OpenSource FPGA
development tools. You will need the following components:
- Verilog compilation and synthesis: Yosys
- Debugging tools: icarus/iverilog and verilator
- FPGA support libraries: IceStorm (Ice40) or Trellis (ECP5)
- Place and root: NextPNR
- Tool to send bitstream to FPGA: ujprog 

Although there exists some precompiled packages, I highly recommend to
get fresh source versions from the source repositories, because the tools
quickly evolve and get better and better ! What follows is a set of
instructions to get and install the latest versions of the tools.
Some steps depend on the type of FPGA installed on your board, refer to
the following table:

| Board     | FPGA family   |
|-----------|---------------|
|IceStick   | Ice40         |
|IceBreaker | Ice40         |
|IceFeather | Ice40         |
|FOMU       | Ice40         |
|ULX3S      | ECP5          |
|OrangeCrab | ECP5          |
|ECP5-EVN   | ECP5          |
|ARTY       | artix-7 (xc7) |

Step 1: FemtoRV
===============
```
$ git clone https://github.com/BrunoLevy/learn-fpga.git
```

For ARTY only
=============

- For the ARTY FPGA family, follow [this link](toolchain_arty.md).
- For other FPGA families, follow the steps below:

Step 2: Yosys and companions
============================


Follow setup instructions from [yosys website](https://github.com/YosysHQ/yosys)

*TL;DR*

Install prerequisites:
```
$ sudo apt-get install build-essential clang bison flex \
  libreadline-dev gawk tcl-dev libffi-dev git \
  graphviz xdot pkg-config python3 libboost-system-dev \
  libboost-python-dev libboost-filesystem-dev zlib1g-dev
```
Get the sources:
```
$ git clone https://github.com/YosysHQ/yosys.git
```
Compile and install it:
```
$ cd yosys
$ make
$ sudo make install
```
icarus/iverilog and verilator
-----------------------------
We will need also analysis and simulation tools. `icarus/iverilog` can do additional checks at
compile time, and is called by `make lint` in our build system. `verilator` does simulation,
which is vital for debugging. It is also used by the build system to transfer hardware configuration
parameters to the firmware.
```
sudo apt-get install iverilog verilator
```

Step 3: FPGA support libraries
==============================

Note that instructions are different, depending on the family of your FPGA:
 - *IceStorm* for Ice40 family (boards: IceStick, IceBreaker, IceFeather, Fomu,...)
 - *Trellis* for ECP5 family (boards: ULX3S, OrangeCrab,...). 

IceStorm (for Ice40 FPGAs)
--------------------------

Follow setup instructions from [icestorm website](https://github.com/YosysHQ/icestorm)

*TL;DR*

Install prerequisites:
```
$ sudo apt-get install build-essential clang bison flex libreadline-dev \
  gawk tcl-dev libffi-dev git mercurial graphviz   \
  xdot pkg-config python python3 libftdi-dev \
  qt5-default python3-dev libboost-all-dev cmake libeigen3-dev
```
Get the sources:
```
$ git clone https://github.com/YosysHQ/icestorm.git
```
Compile and install it:
```
$ cd icestorm
$ make -j 4
$ sudo make install
```

Project Trellis (for ECP5 FPGAs)
--------------------------------

Follow setup instructions from [project trellis website](https://github.com/YosysHQ/prjtrellis)

*TL;DR*

Get the sources:
```
$ git clone --recursive https://github.com/YosysHQ/prjtrellis
```

Compile and install it:
```
$ cd prjtrellis/libtrellis
$ cmake -DCMAKE_INSTALL_PREFIX=/usr/local .
$ make
$ sudo make install
```

Step 4: NextPNR
===============

Follow setup instructions from [nextpnr website](https://github.com/YosysHQ/nextpnr)

*TL;DR*


Get the sources:
```
$ git clone --recursive https://github.com/YosysHQ/nextpnr.git
```

NextPNR compilation and installation for Ice40 FPGAs
----------------------------------------------------
Compile and install it:
```
$ cd nextpnr
$ cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=/usr/local .
$ make -j 4
$ sudo make install
```

NextPNR compilation and installation for ECP5 FPGAs
---------------------------------------------------
Compile and install it:
```
$ cd nextpnr
$ cmake -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_GUI=on .
$ make -j 4
$ sudo make install
```

Step 5: Tool to send bitstream to FPGA
======================================

We need to let normal users program the IceStick through USB. This can be done by
creating a file in `/etc/udev/rules.d`. Instructions are different for different
FPGAs. Then you need a tool to flash the FPGA (see instructions below
to install it). Note: openFPGALoader is a quickly evolving tool that
seems to support most of the FPGAs (TODO: update this tutorial and
instructions with systematic use of openFPGALoader, seems to be the
way to go...).

Ice40 FPGAs (iceprog)
---------------------
Create in `/etc/udev/rules.d` a file `53-lattice-ftdi.rules` 
with the following content:
```
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0660", GROUP="plugdev", TAG+="uaccess"
```
_(no additional tool to install, `iceprog` is included in `icestorm` that we installed in step 3)_

FOMU
----
FOMU includes a Ice40up5k FPGA (Ice40 family) but requires different USB rules and tools:

Create in `/etc/udev/rules.d` a file `99-fomu.rules`
with the following content:
```
SUBSYSTEM=="usb", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="5bf0", MODE="0664", GROUP="plugdev"
```

Install dfu-util:
```
$ sudo apt-get install dfu-util  
```

Plug the FOMU and test it:
```
$ dfu-util -l
```
It should display something like:
```
dfu-util 0.9

Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
Copyright 2010-2016 Tormod Volden and Stefan Schmidt
This program is Free Software and has ABSOLUTELY NO WARRANTY
Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

Found DFU: [1209:5bf0] ver=0101, devnum=20, cfg=1, intf=0, path="1-1", alt=0, name="Fomu PVT running DFU Bootloader v1.9.1", serial="UNKNOWN"
```

ECP5 FPGAs
----------
Creating in `/etc/udev/rules.d` a file `80-fpga-ulx3s.rules`
with the following content:
```
# this is for usb-serial tty device
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6015", \
  MODE="664", GROUP="dialout"
# this is for ujprog libusb access
ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6015", \
  GROUP="dialout", MODE="666"
```
Now install `ujprog` (the tool to send the bitstream to the FPGA):
```
git clone https://github.com/emard/ulx3s-bin
sudo cp ulx3s-bin/usb-jtag/linux-amd64/ujprog /usr/local/bin
```

All FPGAs
---------
The [OpenFPGALoader](https://github.com/trabucayre/openFPGALoader) supports many FPGAs and is easy to use.
To install it, follow [the documentation](https://github.com/trabucayre/openFPGALoader#compile-and-install),
or (TL;DR):
```
$ git clone https://github.com/trabucayre/openFPGALoader.git
$ apt-get install libftdi1-2 libftdi1-dev libhidapi-libusb0 libhidapi-dev libudev-dev cmake pkg-config make g++
$ cd openFPGALoader
$ mkdir build
$ cd build
$ cmake ../ 
$ make
$ sudo make install
```

To see the list of supported boards:
```
$ openFLGALoader --list-boards
```
To flash to SRAM
```
$ openFLGALoader --board my_board my_design.bit
```

To flash to FLASH
```
$ openFLGALoader --board my_board -f my_design.bit
```

Wow, super simple ! Love it !

All set !!!
===========
_Pfiuuu, a long journey, time to have fun now_
