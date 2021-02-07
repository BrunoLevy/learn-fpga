YOSYS_FOMU_OPT=-DFOMU -q -p "synth_ice40 -dsp -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_FOMU_OPT=--json $(PROJECTNAME).json --pcf BOARDS/fomu-pvt.pcf --asc $(PROJECTNAME).asc \
                 --freq 12 --up5k --package uwg30

#######################################################################################################################

FOMU: FOMU.synth FOMU.prog

FOMU.synth: FIRMWARE/firmware.hex 
	TOOLS/make_config.sh -DFOMU
	yosys $(YOSYS_FOMU_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_FOMU_OPT)
	icetime -p BOARDS/fomu-pvt.pcf -P uwg30 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc
	icepack $(PROJECTNAME).asc $(PROJECTNAME).bin
	mv $(PROJECTNAME).bin $(PROJECTNAME).dfu
	dfu-suffix -v 1209 -p 70b1 -a $(PROJECTNAME).dfu

FOMU.show: FIRMWARE/firmware.hex 
	yosys $(YOSYS_FOMU_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_FOMU_OPT) --pcf-allow-unconstrained --gui

FOMU.prog:
	dfu-util -D $(PROJECTNAME).dfu

#######################################################################################################################
