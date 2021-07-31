FEMTORV_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PROJECTNAME=femtosoc
VERILOGS=RTL/$(PROJECTNAME).v

include BOARDS/icestick.mk
include BOARDS/icestick_mecrisp_quintus.mk
include BOARDS/icebreaker.mk
include BOARDS/icefeather.mk
include BOARDS/icesugar.mk
include BOARDS/icesugar_nano.mk
include BOARDS/fomu.mk
include BOARDS/ulx3s.mk
include BOARDS/ecp5_evn.mk
#include BOARDS/arty35_symbiflow.mk
include BOARDS/arty35_yosys_nextpnr.mk

.PHONY: all clean terminal testbench 

################################################################################

all:
	@echo "make one of ICESTICK, ICEFEATHER, ULX3S... (or .synth / .prog)"

clean:
	rm -f *.timings *.asc *.bin *.bit *config *.json *.svf \
              *~ *.vvp *.dfu *.rpt *.blif femtosoc.txt FIRMWARE/config.mk

TERMS=/dev/ttyUSB1 /dev/ttyUSB0 

# Uncomment one of the following lines (pick your favorite term emulator)
terminal: terminal_miniterm
#terminal: terminal_screen
#terminal: terminal_picocom

# make terminal, rule for miniterm
# exit: <ctrl> ]     package: sudo apt-get install python3-serial
terminal_miniterm:
	for i in $(TERMS); do miniterm --dtr=0 $$i 115200; done

# make terminal, rule for screen
# exit: <ctrl> a \   package: sudo apt-get install screen
terminal_screen:
	for i in $(TERMS); do screen $$i 115200; done

# make terminal, rule for picocom
# exit: <ctrl> a \   package: sudo apt-get install picocom
terminal_picocom:
	for i in $(TERMS); do picocom -b 115200 $$i --imap lfcrlf,crcrlf --omap delbs,crlf --send-cmd "ascii-xfr -s -l 30 -n"; done

BENCH: BENCH.verilator

BENCH.firmware_config:
	BOARD=testbench TOOLS/make_config.sh -DBENCH
	(cd FIRMWARE; make libs)

BENCH.icarus:
	(cd RTL; iverilog -IPROCESSOR -IDEVICES femtosoc_bench.v \
         -o ../femtosoc_bench.vvp)
	vvp femtosoc_bench.vvp


BENCH.verilator:
	verilator -DBENCH --top-module femtoRV32_bench \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL  \
	 -LDFLAGS '-lglfw -lGL' \
	 --cc --exe RTL/sim_main.cpp RTL/femtosoc_bench.v
	(cd obj_dir; make -f VfemtoRV32_bench.mk)	 
	obj_dir/VfemtoRV32_bench

################################################################################
