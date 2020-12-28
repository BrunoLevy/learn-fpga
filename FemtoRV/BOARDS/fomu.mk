YOSYS_FOMU_OPT=-DFOMU -q -p "synth_ice40 -relut -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_FOMU_OPT=--force --json $(PROJECTNAME).json --pcf BOARDS/fomu-pvt.pcf --asc $(PROJECTNAME).asc \
                 --freq 48 --up5k --package uwg30

#######################################################################################################################

