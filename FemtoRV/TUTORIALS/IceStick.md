IceStick Tutorial
=================


Step 1: install FPGA development tools
======================================

Yosys
-----

Follow setup instructions from [yosys website](https://github.com/YosysHQ/yosys)

TL;DR

Install prerequisites:

        $ sudo apt-get install build-essential clang bison flex \
          libreadline-dev gawk tcl-dev libffi-dev git \
          graphviz xdot pkg-config python3 libboost-system-dev \
          libboost-python-dev libboost-filesystem-dev zlib1g-dev

Get the sources:

        $ git clone https://github.com/YosysHQ/yosys.git

Compile and install it:

        $ cd yosys
        $ make
	$ sudo make install


IceStorm
--------

Follow setup instructions from [icestorm website](https://github.com/YosysHQ/icestorm)

TL;DR

Install prerequisites:

       $ sudo apt-get install build-essential clang bison flex libreadline-dev \
         gawk tcl-dev libffi-dev git mercurial graphviz   \
         xdot pkg-config python python3 libftdi-dev \
         qt5-default python3-dev libboost-all-dev cmake libeigen3-dev

Get the sources:

        $ git clone https://github.com/YosysHQ/icestorm.git

Compile and install it:

        $ cd icestorm
        $ make -j 4
	$ sudo make install


NextPNR
-------

Follow setup instructions from [nextpnr website](https://github.com/YosysHQ/nextpnr)

TL;DR


Get the sources:

      $ git clone https://github.com/YosysHQ/nextpnr.git

Compile and install it:

      $ cd nextpnr
      $ cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=/usr/local .
      $ make -j 4
      $ sudo make install


Step 2: Configure femtosoc
==========================


Step 3: Configure firmware
==========================


Step 4: Examples
================

Examples with the serial terminal (UART)
----------------------------------------

Examples with the LED matrix
----------------------------

Examples with the OLED screen
------------------------------

