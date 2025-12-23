YOSYS_UPDUINO_OPT=-DICE_BREAKER -q -p "synth_ice40 -abc9 -device u -dsp -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_UPDUINO_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/upduino.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --up5k --package sg48 --opt-timing

#######################################################################################################################

UPDUINO: UPDUINO.firmware_config UPDUINO.synth UPDUINO.prog

UPDUINO.synth: 
	yosys $(YOSYS_UPDUINO_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_UPDUINO_OPT)
	icetime -p BOARDS/upduino.pcf -P sg48 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc 
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

UPDUINO.show: 
	yosys $(YOSYS_UPDUINO_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_UPDUINO_OPT) --gui

UPDUINO.prog:
	iceprog $(PROJECTNAME).bin

UPDUINO.firmware_config:
	BOARD=upduino TOOLS/make_config.sh -DICE_BREAKER
	(cd FIRMWARE; make libs)

UPDUINO.lint:
	verilator -DICE_BREAKER -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
