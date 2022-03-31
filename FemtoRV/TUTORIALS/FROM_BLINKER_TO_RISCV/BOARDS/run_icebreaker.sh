PROJECTNAME=SOC
BOARD=icebreaker
BOARD_FREQ=12
FPGA_VARIANT=up5k
FPGA_PACKAGE=sg48
VERILOGS=$1
yosys -q -DICE_STICK -DNEGATIVE_RESET -DBOARD_FREQ=$BOARD_FREQ -p "synth_ice40 -abc9 -device u -dsp -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
nextpnr-ice40 --force --json $PROJECTNAME.json --pcf BOARDS/$BOARD.pcf --asc $PROJECTNAME.asc --freq $BOARD_FREQ --$FPGA_VARIANT --package $FPGA_PACKAGE --pcf-allow-unconstrained || exit
icetime -p BOARDS/$BOARD.pcf -P $FPGA_PACKAGE -r $PROJECTNAME.timings -d hx1k -t $PROJECTNAME.asc
icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
iceprog $PROJECTNAME.bin || exit
echo DONE.

