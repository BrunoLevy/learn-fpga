YOSYS_ICEBREAKER_OPT=-DICE_BREAKER -q -p "synth_ice40 -dsp -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICEBREAKER_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/icebreaker.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --up5k --package sg48 --opt-timing

#######################################################################################################################

ICEBREAKER: ICEBREAKER.firmware_config ICEBREAKER.synth ICEBREAKER.prog

ICEBREAKER.synth: 
	yosys $(YOSYS_ICEBREAKER_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEBREAKER_OPT)
	icetime -p BOARDS/icebreaker.pcf -P sg48 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc 
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICEBREAKER.show: 
	yosys $(YOSYS_ICEBREAKER_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEBREAKER_OPT) --gui

ICEBREAKER.prog:
	iceprog $(PROJECTNAME).bin

ICEBREAKER.firmware_config:
	BOARD=icebreaker TOOLS/make_config.sh -DICE_BREAKER
	(cd FIRMWARE; make libs)

ICEBREAKER.lint:
	verilator -DICE_BREAKER -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
