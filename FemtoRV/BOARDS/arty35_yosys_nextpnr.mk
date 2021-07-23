PARTNAME=xc7a35tcsg324-1
DB_DIR=/usr/share/nextpnr/prjxray-db
CHIPDB_DIR=/usr/share/nextpnr/xilinx-chipdb
PART=xc7a35tcsg324-1
YOSYS_ARTY_OPT=-DARTY -q -p "scratchpad -set xilinx_dsp.multonly 1" \
                         -p "synth_xilinx -flatten -nowidelut -abc9 -arch xc7 -top $(PROJECTNAME); write_json $(PROJECTNAME).json"

ARTY: ARTY.firmware_config ARTY.synth ARTY.prog

ARTY.synth:
	yosys ${YOSYS_ARTY_OPT} ${VERILOGS}
	nextpnr-xilinx --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/arty.xdc --json ${PROJECTNAME}.json --write ${PROJECTNAME}_routed.json --fasm ${PROJECTNAME}.fasm
	fasm2frames --part ${PART} --db-root ${DB_DIR}/artix7 ${PROJECTNAME}.fasm > ${PROJECTNAME}.frames
	xc7frames2bit --part_file ${DB_DIR}/artix7/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECTNAME}.frames --output_file ${PROJECTNAME}.bit

ARTY.prog_fast:
	openFPGALoader --freq 30e6 --board arty femtosoc.bit

ARTY.prog:
	openFPGALoader --freq 30e6 --board arty -f femtosoc.bit

ARTY.firmware_config:
	BOARD=arty TOOLS/make_config.sh -DARTY
	(cd FIRMWARE; make libs)
