USED_FREQ=25
YOSYS_ICE40HX1K_EVB_OPT=-DICE40HX1K_EVB -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICE40HX1K_EVB_OPT=--json $(PROJECTNAME).json --pcf BOARDS/ice40hx1k_evb.pcf --asc $(PROJECTNAME).asc \
			  --freq $(USED_FREQ) --hx1k --package vq100 --opt-timing
#need to implement MHz clockwork for 50 33.333 25 20
ICE40HX1K_EVB: ICE40HX1K_EVB.firmware_config ICE40HX1K_EVB.synth ICE40HX1K_EVB.prog

ICE40HX1K_EVB.synth:
	yosys $(YOSYS_ICE40HX1K_EVB_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE40HX1K_EVB_OPT)
	icetime -p BOARDS/ice40hx1k_evb.pcf -P vq100 -r $(PROJECTNAME).timings -d hx1k -t $(PROJECTNAME).asc
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICE40HX1K_EVB.show:
	yosys $(YOSYS_ICE40HX1K_EVB_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE40HX1K_EVB_OPT) --gui

ICE40HX1K_EVB.prog:
	iceprogduino $(PROJECTNAME).bin

ICE40HX1K_EVB.firmware_config:
	BOARD=ice40hx1k_evb TOOLS/make_config.sh -DICE40HX1K_EVB
	(cd FIRMWARE; make libs)

ICE40HX1K_EVB.lint:
	verilator -DICE40HX1K_EVB -DBENCH --lint-only --top-module $(PROJECTNAME) \
		-IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)
