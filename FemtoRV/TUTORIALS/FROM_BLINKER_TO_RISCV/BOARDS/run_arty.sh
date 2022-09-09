#!/usr/bin/env bash
PROJECT_NAME=SOC
DB_DIR=/usr/share/nextpnr/prjxray-db
CHIPDB_DIR=/usr/share/nextpnr/xilinx-chipdb
PART=xc7a35tcsg324-1
VERILOGS=$1
BOARD_FREQ=100
CPU_FREQ=75

set -ex
yosys -DARTY -DBOARD_FREQ=$BOARD_FREQ -DCPU_FREQ=$CPU_FREQ -p "scratchpad -set xilinx_dsp.multonly 1" -p "synth_xilinx -nowidelut -flatten -abc9 -arch xc7 -top SOC; write_json ${PROJECT_NAME}.json" ${VERILOGS}
nextpnr-xilinx --chipdb ${CHIPDB_DIR}/xc7a35t.bin --xdc BOARDS/arty.xdc --json ${PROJECT_NAME}.json --write ${PROJECT_NAME}_routed.json --fasm ${PROJECT_NAME}.fasm
fasm2frames --part ${PART} --db-root ${DB_DIR}/artix7 ${PROJECT_NAME}.fasm > ${PROJECT_NAME}.frames
xc7frames2bit --part_file ${DB_DIR}/artix7/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECT_NAME}.frames --output_file ${PROJECT_NAME}.bit
#To send to SRAM:
openFPGALoader --board arty ${PROJECT_NAME}.bit
#To send to FLASH: 
#openFPGALoader --board arty -f ${PROJECT_NAME}.bit
