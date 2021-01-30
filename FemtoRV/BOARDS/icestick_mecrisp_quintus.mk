#######################################################################################################################
# Special version for mecrisp-quintus (Forth interpreter) on IceStick
# mecrisp website: http://mecrisp.sourceforge.net/

YOSYS_ICESTICK_MECRISP_QUINTUS_OPT=-DICE_STICK -q \
                 -p "synth_ice40 -top $(PROJECTNAME) -json $(PROJECTNAME).json -blif $(PROJECTNAME).blif -abc2 -relut"

NEXTPNR_ICESTICK_MECRISP_QUINTUS_OPT=--freq 48 --hx1k --package tq144 \
                                     --asc $(PROJECTNAME).asc --pcf BOARDS/icestick_mecrisp_quintus.pcf \
                                     --json $(PROJECTNAME).json --ignore-loops --pcf-allow-unconstrained --seed 42

VERILOGS_MECRISP_QUINTUS=RTL/femtosoc_icestick_mecrisp_quintus.v

#######################################################################################################################

ICESTICK_MECRISP_QUINTUS: ICESTICK_MECRISP_QUINTUS.synth ICESTICK_MECRISP_QUINTUS.prog

ICESTICK_MECRISP_QUINTUS.synth: FIRMWARE/firmware.hex
	yosys $(YOSYS_ICESTICK_MECRISP_QUINTUS_OPT) $(VERILOGS_MECRISP_QUINTUS)
	nextpnr-ice40 $(NEXTPNR_ICESTICK_MECRISP_QUINTUS_OPT)
	icetime -p BOARDS/icestick_mecrisp_quintus.pcf -P tq144 -r $(PROJECTNAME).timings -d hx1k -t $(PROJECTNAME).asc 
	icepack $(PROJECTNAME).asc $(PROJECTNAME).bin

ICESTICK_MECRISP_QUINTUS.show: FIRMWARE/firmware.hex
	yosys $(YOSYS_ICESTICK_MECRISP_QUINTUS_OPT) $(VERILOGS_MECRISP_QUINTUS)
	nextpnr-ice40 $(NEXTPNR_ICESTICK_MECRISP_QUINTUS_OPT) --gui

ICESTICK_MECRISP_QUINTUS.prog:
	iceprog $(PROJECTNAME).bin

#######################################################################################################################
