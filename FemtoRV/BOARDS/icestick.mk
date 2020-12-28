YOSYS_ICESTICK_OPT=-DICE_STICK -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICESTICK_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/icestick.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --hx1k --package tq144

#######################################################################################################################

ICESTICK: ICESTICK.synth ICESTICK.prog

ICESTICK.synth: FIRMWARE/firmware.hex
	yosys $(YOSYS_ICESTICK_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICESTICK_OPT)
	icetime -p BOARDS/icestick.pcf -P tq144 -r $(PROJECTNAME).timings -d hx1k -t $(PROJECTNAME).asc
	icepack $(PROJECTNAME).asc $(PROJECTNAME).bin

ICESTICK.show: FIRMWARE/firmware.hex
	yosys $(YOSYS_ICESTICK_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICESTICK_OPT) --gui

ICESTICK.prog:
	iceprog $(PROJECTNAME).bin

#######################################################################################################################
