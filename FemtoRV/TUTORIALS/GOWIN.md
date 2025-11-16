GOWIN TANG NANO Tutorial
========================

There exists packages for Linux distributions
(`nextpnr-gowin`,`nextpnr-gowin-chipdb`,`python3-apycula`) but they
are outdated, one needs to use the new `nextpnr-himbaechel` instead
(thank you @YRabbit for telling me).

Let's see how to install everything from the sources:

Step 1: Yosys
=============

```
git clone --recurse-submodules https://github.com/YosysHQ/yosys.git
cd yosys
make
sudo make install
```

Step 2: NextPNR
===============

Get the sources:
```
$ git clone --recursive https://github.com/YosysHQ/nextpnr.git
```

NextPNR compilation and installation for Ice40 FPGAs
----------------------------------------------------
Compile and install it:
```
$ cd nextpnr
$ cmake . -B build -DARCH=himbaechel -DHIMBAECHEL_UARCH=gowin -DCMAKE_INSTALL_PREFIX=/usr/local .
$ cd build
$ make -j 4
$ sudo make install
```
