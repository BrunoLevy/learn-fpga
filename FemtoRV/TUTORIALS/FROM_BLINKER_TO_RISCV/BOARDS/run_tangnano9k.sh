PROJECTNAME=SOC
BOARD=tangnano9k
BOARD_FREQ=27
CPU_FREQ=40
FPGA_FAMILY=GW1N-9C
FPGA_DEVICE=GW1NR-LV9QN88PC6/I5
VERILOGS=$1

yosys -q -DTANGNANO_9K -DBOARD_FREQ=$BOARD_FREQ -DCPU_FREQ=$CPU_FREQ -p "synth_gowin -top $PROJECTNAME -json $PROJECTNAME-synth.json " $VERILOGS  || exit
nextpnr-himbaechel --json $PROJECTNAME-synth.json --write ${PROJECTNAME}.json --device ${FPGA_DEVICE} --vopt family=${FPGA_FAMILY} --vopt cst=BOARDS/tangnano9k.cst || exit
gowin_pack -d ${FPGA_FAMILY} -o ${PROJECTNAME}.fs ${PROJECTNAME}.json
openFPGALoader -c ft2232 ${PROJECTNAME}.fs

