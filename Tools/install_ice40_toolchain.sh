# Compiles and installs yosys/nextpnr for ICE40-based FPGAs on Ubuntu
# You will need to run it as root (sudo ./install_ice40_toolchain.sh)
# Bruno Levy, Nov. 2022

mkdir /tmp/BUILD
cd /tmp/BUILD

echo "YOSYS dependencies"

apt-get install build-essential clang bison flex \
  libreadline-dev gawk tcl-dev libffi-dev git \
  graphviz xdot pkg-config python3 libboost-system-dev \
  libboost-python-dev libboost-filesystem-dev zlib1g-dev

echo "YOSYS"

git clone https://github.com/YosysHQ/yosys.git
(cd yosys; make -j 4; make install)

echo "ICARUS/IVERILOG and VERILATOR"

apt-get install iverilog verilator

echo "ICESTORM dependencies"

apt-get install build-essential clang bison flex libreadline-dev \
  gawk tcl-dev libffi-dev git mercurial graphviz   \
  xdot pkg-config python python3 libftdi-dev \
  qt5-default python3-dev libboost-all-dev cmake libeigen3-dev

echo "ICESTORM"

git clone https://github.com/YosysHQ/icestorm.git

(cd icestorm; make -j 4; make install)

echo "NEXTPNR"

git clone --recursive https://github.com/YosysHQ/nextpnr.git

(cd nextpnr; cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=/usr/local .; make -j 4; make install)

echo "UDEV RULES"
echo 'ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0660", GROUP="plugdev", TAG+="uaccess"' > /etc/udev/rules.d/53-lattice-ftdi.rules 
