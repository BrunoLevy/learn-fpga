#!/usr/bin/env bash
PROJECT_NAME=blinky
DB_DIR=/usr/share/nextpnr/prjxray-db
CHIPDB_DIR=/usr/share/nextpnr/xilinx-chipdb
PART=xc7a35tcsg324-1

set -ex
yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top top; write_json ${PROJECT_NAME}.json" ${PROJECT_NAME}.v
nextpnr-xilinx --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc arty.xdc --json ${PROJECT_NAME}.json --write ${PROJECT_NAME}_routed.json --fasm ${PROJECT_NAME}.fasm
fasm2frames --part ${PART} --db-root ${DB_DIR}/artix7 ${PROJECT_NAME}.fasm > ${PROJECT_NAME}.frames
xc7frames2bit --part_file ${DB_DIR}/artix7/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECT_NAME}.frames --output_file ${PROJECT_NAME}.bit
#To send to SRAM:
openFPGALoader --board arty ${PROJECT_NAME}.bit
#To send to FLASH: 
#openFPGALoader --board arty -f ${PROJECT_NAME}.bit