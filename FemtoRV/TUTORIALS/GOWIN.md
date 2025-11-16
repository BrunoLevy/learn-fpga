GOWIN TANG NANO Tutorial
========================

There exists packages for Linux distributions
(`nextpnr-gowin`,`nextpnr-gowin-chipdb`,`python3-apycula`) but they
are outdated, one needs to use the new `nextpnr-himbaechel` instead
(thank you @YRabbit for telling me).

Let's see how to install everything from the sources:

1) Yosys
--------
```
git clone --recurse-submodules https://github.com/YosysHQ/yosys.git
cd yosys
make
sudo make install
```
