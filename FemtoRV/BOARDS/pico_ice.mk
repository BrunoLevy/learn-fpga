YOSYS_PICOICE_OPT=-DPICO_ICE -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_PICOICE_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/pico_ice.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --up5k --package sg48 --opt-timing


#######################################################################################################################

PICOICE: PICOICE.firmware_config PICOICE.synth PICOICE.prog

PICOICE.synth:
	yosys $(YOSYS_PICOICE_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_PICOICE_OPT)
	icetime -p BOARDS/pico_ice.pcf -P sg48 -r $(PROJECTNAME).timings -d up5k -t $(PROJECTNAME).asc
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

PICOICE.show:
	yosys $(YOSYS_PICOICE_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_PICOICE_OPT) --gui

PICOICE.prog:
	# Upload using DFU slot alt 0 (SPI), so the image is permanent
	dfu-util -D $(PROJECTNAME).bin -a 0

PICOICE.firmware_config:
	BOARD=PICOICE TOOLS/make_config.sh -DPICO_ICE
	(cd FIRMWARE; make libs)

PICOICE.lint:
	verilator -DPICO_ICE -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
