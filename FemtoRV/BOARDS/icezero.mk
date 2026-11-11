MINFREQ=12 #i'm a novice, not sure but giving lax timing requirements seem to work for this 100MHz clocked board
YOSYS_ICEZERO_OPT=-DICE_ZERO -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ICEZERO_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/icezero.pcf --asc $(PROJECTNAME).asc \
                     --freq $(MINFREQ) --hx8k --package tq144:4k --opt-timing
#NEXTPNR_ICEZERO_OPT=--force --seed 18 --json $(PROJECTNAME).json --pcf BOARDS/icezero.pcf --asc $(PROJECTNAME).asc \
#                     --freq $(XTAL_FREQ) --hx8k --package tq144:4k --opt-timing


#######################################################################################################################

ICEZERO: ICEZERO.firmware_config ICEZERO.synth ICEZERO.prog

ICEZERO.synth:
	yosys $(YOSYS_ICEZERO_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEZERO_OPT)
	icetime -p BOARDS/icezero.pcf -P tq144:4k -r $(PROJECTNAME).timings -d hx8k -t $(PROJECTNAME).asc
	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

#ICEZERO.synth:
#	yosys $(YOSYS_ICEZERO_OPT) $(VERILOGS)
#	nextpnr-ice40 $(NEXTPNR_ICEZERO_OPT)
#	icetime -c $(XTAL_FREQ) -p BOARDS/icezero.pcf -P tq144:4k -r $(PROJECTNAME).timings -d hx8k -t $(PROJECTNAME).asc
#	icepack -s $(PROJECTNAME).asc $(PROJECTNAME).bin

ICEZERO.show:
	yosys $(YOSYS_ICEZERO_OPT) $(VERILOGS)
	nextpnr-ice40 $(NEXTPNR_ICEZERO_OPT) --gui

ICEZERO.prog:
        rcp $(PROJECTNAME).bin lattice@ice.local://home/lattice/trenz
	#iceprog $(PROJECTNAME).bin

ICEZERO.firmware_config:
	BOARD=icezero TOOLS/make_config.sh -DICE_ZERO
	(cd FIRMWARE; make libs)

ICEZERO.lint:
	verilator -DICE_ZERO -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)

#######################################################################################################################
