Installing open-source tools for ARTIX-7 FPGAs
==============================================

There are two possible toolchains for ARTIX-7, either symbiflow
(all-in-one, integrated, easier to install) or yosys + xray + nextpnr-xilinx
(more complicated to install, but more up to date, and uses nextpnr
instead of the heavier vpr).

Yosys/NextPNR/ProjectXRay
=========================

Step 1: yosys
-------------

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

Step 2: prjxray
---------------

Either generate the database (but you need Vivado) or use a
pre-generated one. OK, let's use the pre-generated one.

Follow the README from [prjxray](https://github.com/SymbiFlow/prjxray).

*TL;DR*

```
$ git clone https://github.com/SymbiFlow/prjxray.git
$ cd prjxray
$ git submodule update --init --recursive
$ make build
$ sudo make install
$ ./download-latest-db.sh
$ sudo mkdir -p /usr/share/nextpnr/
$ sudo cp -r database /usr/share/nextpnr/prjxray-db
$ sudo apt-get install python3 python3-pip python3-yaml
# NOT NEEDED ? $ sudo -H pip3 install -r requirements.txt # Rem: Arch Linux and Fedora uses *need* to read the README before.
```

Step 3: nextpnr-xilinx
======================
Did not manage to build it with the gui, because on my box it gives a missing symbol error in boost-python, so I deactivated it.
```
$ git clone https://github.com/gatecat/nextpnr-xilinx.git
$ cd nextpnr-xilinx
$ git submodule init
$ git submodule update
$ mkdir build
$ cd build
$ cmake ../ -DARCH=xilinx -DBUILD_GUI=OFF -DBUILD_PYTHON=OFF 
$ make
$ sudo make install
```

One more thing, you will need to generate the chipdb (whatever that
means, I do not understand everything here...). Learnt that from the 'building the Arty example' of 
[this webpage](https://github.com/gatecat/nextpnr-xilinx)). Needs to
be adapted if you have a 100t instead of 35t.
```
$ cd nextpnr-xilinx
$ python3 xilinx/python/bbaexport.py --device xc7a35tcsg324-1 --bba xilinx/xc7a35t.bba
$ build/bbasm --l xilinx/xc7a35t.bba xilinx/xc7a35t.bin
$ sudo mkdir -p /usr/share/nextpnr/xilinx-chipdb
$ sudo cp xilinx/xc7a35t.bin /usr/share/nextpnr/xilinx-chipdb/
```

Here we go ! Now time to
- install openFPGALoader (at the end of [the general toolchain tutorial](toolchain.md))
- plug your ARTY
- run `makeit.sh` in [`basic/ARTY/ARTY_blink`](https://github.com/BrunoLevy/learn-fpga/tree/master/Basic/ARTY/ARTY_blink).
If everything went well, you will see a colorful blinky !

ALTERNATIVE: SYMBIFLOW 
======================

Step 1: Install symbiflow
-------------------------

To do that, a (custom) version of [symbiflow-magic](https://github.com/merledu/symbiflow-magic) is bundled with FemtoRV.
Symbiflow-magic is a makefile that downloads and configures a pre-compiled version of symbiflow for ARTIX-7.
The version bundled with FemtoRV fixes a couple of [issues](https://github.com/merledu/symbiflow-magic/issues/1).
```
$ cd learn-fpga/FemtoRV
$ make -f TOOLS/get_symbifow.mk
```

It will download and install several packages (takes a while...)

Step 2: post-install step
-------------------------

Add anaconda initialization to your shell startup file as follows:
```
$ $HOME/opt/symbiflow/xc7/conda/bin/conda init $SHELL
```

Add the following line to your shell startup file (`.bashrc` if you use bash).
```
export PATH=/home/blevy/opt/symbiflow/xc7/install/bin/:$PATH
conda activate xc7
```

Start a new terminal window. If everything went well, the prompt should start with `(xc7)`.

Edit `learn_fpga/FemtoRV/Makefile`, comment the line with `arty_yosys_nextpnr.mk` and 
uncomment the one with `arty35_symbiflow.mk`.
