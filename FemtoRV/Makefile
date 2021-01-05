PROJECTNAME=femtosoc
VERILOGS=RTL/$(PROJECTNAME).v

include BOARDS/icestick.mk
include BOARDS/icefeather.mk
include BOARDS/icesugar.mk
include BOARDS/icesugar_nano.mk
include BOARDS/fomu.mk
include BOARDS/ulx3s.mk
include BOARDS/ecp5_evn.mk

.PHONY: all clean testbench 

################################################################################

all:
	@echo "make one of ICESTICK, ICEFEATHER, ULX3S... (or .synth / .prog)"

clean:
	rm -f *.timings *.asc *.bin *.bit *config *.json *.svf \
              *~ *.vvp *.dfu *.rpt


FIRMWARE/firmware.hex:
	(cd FIRMWARE; ./make_firmware.sh EXAMPLES/hello.c)

TERMS=/dev/ttyUSB0 /dev/ttyUSB1

terminal:
        # exit: <ctrl> ]     package : sudo apt-get install python3-serial
	for i in $(TERMS); do miniterm --dtr=0 $$i 115200; done
#       # exit: <ctrl> a \   package : sudo apt-get install screen
#	for i in $(TERMS); do screen $$i 115200; done 

testbench:
	(cd RTL; iverilog -IPROCESSOR -IDEVICES femtosoc_bench.v \
         -o ../femtosoc_bench.vvp)
	vvp femtosoc_bench.vvp

lint:
	verilator --lint-only -DPASSTHROUGH_PLL --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

################################################################################
