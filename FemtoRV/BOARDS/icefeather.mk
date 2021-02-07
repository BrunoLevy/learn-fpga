YOSYS_ICEFEATHER_OPT=-DICE_FEATHER -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICEFEATHER_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/icefeather.pcf --asc $(PROJECTNAME).asc \
                       --freq 12 --up5k --package sg48

#######################################################################################################################

ICEFEATHER: ICEFEATHER.synth ICEFEATHER.prog

ICEFEATHER.synth: FIRMWARE/firmware.hex 
	TOOLS/make_config.sh -DICE_FEATHER
	yosys $(YOSYS_ICEFEATHER_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEFEATHER_OPT)
	icetime -p BOARDS/icefeather.pcf -P sg48 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc
	icepack $(PROJECTNAME).asc $(PROJECTNAME).bin

ICEFEATHER.show: FIRMWARE/firmware.hex 
	yosys $(YOSYS_ICEFEATHER_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEFEATHER_OPT) --gui

ICEFEATHER.prog:
	iceprog $(PROJECTNAME).bin

