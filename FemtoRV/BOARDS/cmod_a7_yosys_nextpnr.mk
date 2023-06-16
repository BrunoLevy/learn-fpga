PARTNAME=xc7a35tcpg236-1
DB_DIR=/usr/share/nextpnr/prjxray-db
CHIPDB_DIR=/usr/share/nextpnr/xilinx-chipdb
PART=xc7a35tcpg236-1

# cascading DSPs not supported yet by nextpnr-xilinx -----.
# -DCMODA7 ... -q      -p " ... -nowidelut ..."             v
YOSYS_CMODA7_OPT=-DCMODA7 -p "scratchpad -set xilinx_dsp.multonly 1" \
                      -p "synth_xilinx -nowidelut -flatten -abc9 -arch xc7 -top $(PROJECTNAME); write_json $(PROJECTNAME).json"

CMODA7: CMODA7.firmware_config CMODA7.synth CMODA7.prog

CMODA7.synth:
	yosys ${YOSYS_CMODA7_OPT} ${VERILOGS} > log.txt
	nextpnr-xilinx --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/cmod_a7.xdc --json ${PROJECTNAME}.json --write ${PROJECTNAME}_routed.json --fasm ${PROJECTNAME}.fasm
	fasm2frames --part ${PART} --db-root ${DB_DIR}/artix7 ${PROJECTNAME}.fasm > ${PROJECTNAME}.frames
	xc7frames2bit --part_file ${DB_DIR}/artix7/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECTNAME}.frames --output_file ${PROJECTNAME}.bit

# Display "floorplan", does not work for now (seems that floorplan
# display is implemented, but menu entries "assign budget" and "route"
# are grayed out.
CMODA7.show:
#	yosys ${YOSYS_CMODA7_OPT} ${VERILOGS}
	nextpnr-xilinx --gui --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/cmod_a7.xdc --json ${PROJECTNAME}.json 

CMODA7.prog_fast:
	openFPGALoader --freq 30e6 -c digilent --fpga-part xc7a35 femtosoc.bit

CMODA7.prog:
	openFPGALoader --freq 30e6 -c digilent --fpga-part xc7a35tcpg236 -f femtosoc.bit

CMODA7.firmware_config:
	BOARD=cmod_a7 TOOLS/make_config.sh -DCMODA7
	(cd FIRMWARE; make libs)

CMODA7.lint:
	verilator -DCMODA7 -DBENCH --lint-only --top-module $(PROJECTNAME) \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL $(VERILOGS)
