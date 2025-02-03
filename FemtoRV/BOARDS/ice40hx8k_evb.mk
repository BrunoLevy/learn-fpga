YOSYS_ICE40HX8K_EVB_OPT=-DICE40HX8K_EVB -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICE40HX8K_EVB_OPT=--json $(PROJECTNAME).json --pcf BOARDS/ice40hx8k_evb.pcf --asc $(PROJECTNAME).asc \
			  --freq 20 --hx8k --package ct256 --opt-timing

ICE40HX8K_EVB: ICE40HX8K_EVB.firmware_config ICE40HX8K_EVB.synth ICE40HX8K_EVB.prog

ICE40HX8K_EVB.synth:
	yosys $(YOSYS_ICE40HX8K_EVB_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE40HX8K_EVB_OPT)
	icetime -p BOARDS/ice40hx8k_evb.pcf -P ct256 -r $(PROJECTNAME).timings -d hx8k -t $(PROJECTNAME).asc
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICE40HX8K_EVB.show:
	yosys $(YOSYS_ICE40HX8K_EVB_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE40HX8K_EVB_OPT) --gui

ICE40HX8K_EVB.prog:
	iceprogduino $(PROJECTNAME).bin

ICE40HX8K_EVB.firmware_config:
	BOARD=ice40hx8k_evb TOOLS/make_config.sh -DICE40HX8K_EVB
	(cd FIRMWARE; make libs)

ICE40HX8K_EVB.lint:
	verilator -DICE40HX8K_EVB -DBENCH --lint-only --top-module $(PROJECTNAME) \
		-IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)
