FPGA_ROOT=/usr/local/bin
PROJECTNAME=SOC
BOARD=tangnano9k
BOARD_FREQ=27
CPU_FREQ=45
FPGA_FAMILY=GW1N-9C
FPGA_DEVICE=GW1NR-LV9QN88PC6/I5
VERILOGS=$1

$FPGA_ROOT/yosys -q -DTANGNANO9K -DBOARD_FREQ=$BOARD_FREQ -DCPU_FREQ=$CPU_FREQ -p "synth_gowin -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
$FPGA_ROOT/nextpnr-himbaechel --force --timing-allow-fail --json $PROJECTNAME.json --vopt cst=BOARDS/$BOARD.cst --write pnr_$PROJECTNAME.json --device $FPGA_DEVICE --vopt family=$FPGA_FAMILY || exit
gowin_pack -d $FPGA_FAMILY -o $PROJECTNAME.fs pnr_$PROJECTNAME.json || exit
/usr/bin/openFPGALoader -b $BOARD $PROJECTNAME.fs
