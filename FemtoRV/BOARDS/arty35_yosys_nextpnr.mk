PARTNAME=xc7a35tcsg324-1
DB_DIR=/usr/share/nextpnr/prjxray-db
CHIPDB_DIR=/usr/share/nextpnr/xilinx-chipdb
PART=xc7a35tcsg324-1

# cascading DSPs not supported yet by nextpnr-xilinx -----.
# -DARTY ... -q      -p " ... -nowidelut ..."             v
YOSYS_ARTY_OPT=-DARTY -p "scratchpad -set xilinx_dsp.multonly 1" \
                      -p "synth_xilinx -nowidelut -flatten -abc9 -arch xc7 -top $(PROJECTNAME); write_json $(PROJECTNAME).json"

ARTY: ARTY.firmware_config ARTY.synth ARTY.prog

ARTY.synth:
	yosys ${YOSYS_ARTY_OPT} ${VERILOGS} > log.txt
	nextpnr-xilinx --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/arty.xdc --json ${PROJECTNAME}.json --write ${PROJECTNAME}_routed.json --fasm ${PROJECTNAME}.fasm
	fasm2frames --part ${PART} --db-root ${DB_DIR}/artix7 ${PROJECTNAME}.fasm > ${PROJECTNAME}.frames
	xc7frames2bit --part_file ${DB_DIR}/artix7/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECTNAME}.frames --output_file ${PROJECTNAME}.bit

# Display "floorplan", does not work for now (seems that floorplan
# display is implemented, but menu entries "assign budget" and "route"
# are grayed out.
ARTY.show:
#	yosys ${YOSYS_ARTY_OPT} ${VERILOGS}
	nextpnr-xilinx --gui --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/arty.xdc --json ${PROJECTNAME}.json 

ARTY.prog_fast:
	openFPGALoader --freq 30e6 --board arty femtosoc.bit

ARTY.prog:
	openFPGALoader --freq 30e6 --board arty -f femtosoc.bit

ARTY.firmware_config:
	BOARD=arty TOOLS/make_config.sh -DARTY
	(cd FIRMWARE; make libs)
