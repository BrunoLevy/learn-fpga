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

Step 2: Apycula
===============
```
pip install apycula --break-system-packages
```

Step 3: NextPNR
===============

```
git clone --recursive https://github.com/YosysHQ/nextpnr.git
cd nextpnr
cmake . -B build -DARCH=himbaechel -DHIMBAECHEL_UARCH=gowin -DHIMBAECHEL_GOWIN_DEVICES=GW1N-9C -DCMAKE_INSTALL_PREFIX=/usr/local
cd build
make -j 4
sudo make install
```
