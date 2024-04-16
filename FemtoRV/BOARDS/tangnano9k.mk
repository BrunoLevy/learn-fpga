DEVICE=GW1NR-LV9QN88PC6/I5
FAMILY=GW1N-9C

YOSYS_TANGNANO9K_OPT=-q -p "synth_gowin -top $(PROJECTNAME); write_json $(PROJECTNAME)-synth.json"
NEXTPNR_TANGNANO9K_OPT=--device ${DEVICE} --vopt family=${FAMILY} --vopt cst=BOARDS/tangnano9k.cst

TANGNANO9K: TANGNANO9K.firmware_config TANGNANO9K.synth TANGNANO9K.prog

TANGNANO9K.synth: FIRMWARE/firmware.hex 
	yosys ${YOSYS_TANGNANO9K_OPT} ${VERILOGS}
	nextpnr-himbaechel --json ${PROJECTNAME}-synth.json --write ${PROJECTNAME}.json
	gowin_pack -d ${DEVICE} -o $(PROJECTNAME).bit

TANGNANO9K.prog:
	openFPGALoader --board tangnano9k femtosoc.bit

TANGNANO9K.firmware_config:
	BOARD=tangnano9k TOOLS/make_config.sh -DTANGNANO9K
	(cd FIRMWARE; make libs)

