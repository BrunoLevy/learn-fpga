PROJECTNAME=femtosoc
VERILOGS=RTL/$(PROJECTNAME).v

# ICESTICK
YOSYS_ICESTICK_OPT=-DICE_STICK -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICESTICK_OPT=--force --json $(PROJECTNAME).json --pcf icestick.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --hx1k --package tq144

# ULX3S
YOSYS_ULX3S_OPT=-DULX3S -q -p "synth_ecp5 -abc9 -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ULX3S_OPT=--force --timing-allow-fail --json $(PROJECTNAME).json --lpf ulx3s.lpf \
                  --textcfg $(PROJECTNAME)_out.config --85k --freq 25 --package CABGA381

# ECP5_EVN
YOSYS_ECP5_EVN_OPT=-DECP5_EVN -q -p "synth_ecp5 -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ECP5_EVN_OPT=--force --json $(PROJECTNAME).json --lpf ecp5_evn.lpf \
                     --textcfg $(PROJECTNAME)_out.config --um5g-85k --freq 50 --package CABGA381

.PHONY: all clean testbench \
        ULX3S    ULX3S.synth    ULX3S.prog    ULX3S.prog_flash \
        ECP5_EVN ECP5_EVN.synth ECP5_EVN.prog                  \
        ICESTICK ICESTICK.synth ICESTICK.prog

all:
	@echo "make one of ICESTICK, ULX3S, ECP5_EVN (or .synth / .prog)"


clean:
	rm -f *.timings *.asc *.bin *.bit *config *.json *.svf *~

#######################################################################################################################

FIRMWARE/firmware.hex:
	(cd FIRMWARE; ./make_firmware.sh EXAMPLES/hello.c)

#######################################################################################################################

terminal:
	miniterm --dtr=0 /dev/ttyUSB1 115200   # exit: <ctrl> ]     install package : sudo apt-get install python3-serial
#	screen /dev/ttyUSB1 115200             # exit: <ctrl> a \   install package : sudo apt-get install screen



#######################################################################################################################

ICESTICK: ICESTICK.synth ICESTICK.prog

ICESTICK.synth: FIRMWARE/firmware.hex
	yosys $(YOSYS_ICESTICK_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICESTICK_OPT)
	icetime -p icestick.pcf -P tq144 -r $(PROJECTNAME).timings -d hx1k -t $(PROJECTNAME).asc
	icepack $(PROJECTNAME).asc $(PROJECTNAME).bin

ICESTICK.prog:
	iceprog $(PROJECTNAME).bin

#######################################################################################################################

ULX3S: ULX3S.synth ULX3S.prog

ULX3S.synth: FIRMWARE/firmware.hex
	yosys $(YOSYS_ULX3S_OPT) $(VERILOGS)
	nextpnr-ecp5 $(NEXTPNR_ULX3S_OPT)
	ecppack --compress --svf-rowsize 100000 --svf $(PROJECTNAME).svf $(PROJECTNAME)_out.config $(PROJECTNAME).bit

ULX3S.prog: # program once (lost if device restarted)
	ujprog $(PROJECTNAME).bit           

ULX3S.prog_flash: # program permanently
	ujprog -j FLASH $(PROJECTNAME).bit  

#######################################################################################################################

ECP5_EVN:ECP5_EVN.synth ECP5_EVN.prog

ECP5_EVN.synth: FIRMWARE/firmware.hex
	yosys $(YOSYS_ECP5_EVN_OPT) $(VERILOGS)
	nextpnr-ecp5 $(NEXTPNR_ECP5_EVN_OPT)
	ecppack --compress --svf-rowsize 100000 --svf $(PROJECTNAME).svf $(PROJECTNAME)_out.config $(PROJECTNAME).bit

ECP5_EVN.prog:
	openocd -f ecp5-evn.cfg -c "transport select jtag; init; svf $(PROJECTNAME).svf; exit"

#######################################################################################################################

testbench:
	(cd RTL; iverilog femtosoc_bench.v -o ../femtosoc_bench)
	vvp femtosoc_bench

#######################################################################################################################
