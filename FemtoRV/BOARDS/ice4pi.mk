# ICE4PI is 99% identical with ICE_STICK, so we keep the -DICE_STICK and just add -DICE4PI
YOSYS_ICE4PI_OPT=-DICE_STICK -DICE4PI -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICE4PI_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/ice4pi.pcf --asc $(PROJECTNAME).asc \
                     --freq 12 --hx1k --package tq144 --opt-timing


#######################################################################################################################

ICE4PI: ICE4PI.firmware_config ICE4PI.synth ICE4PI.prog

ICE4PI.synth: 
	yosys $(YOSYS_ICE4PI_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE4PI_OPT)
	icetime -p BOARDS/ice4pi.pcf -P tq144 -r $(PROJECTNAME).timings -d hx1k -t $(PROJECTNAME).asc 
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICE4PI.show: 
	yosys $(YOSYS_ICE4PI_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICE4PI_OPT) --gui

ICE4PI.prog:
	sudo TOOLS/ice4pi_prog $(PROJECTNAME).bin

ICE4PI.firmware_config:
	BOARD=icestick TOOLS/make_config.sh -DICE_STICK -DICE4PI
	(cd FIRMWARE; make libs)

ICE4PI.lint:
	verilator -DICE_STICK -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
