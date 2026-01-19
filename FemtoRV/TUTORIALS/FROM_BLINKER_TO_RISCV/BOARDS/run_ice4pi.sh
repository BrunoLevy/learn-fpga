PROJECTNAME=SOC
BOARD=icestick
BOARD_FREQ=12
#CPU_FREQ=45
#20 works
#CPU_FREQ=20
#35 for step24.v to be inside timing requirements
#CPU_FREQ=35
#go back to default to see if it gets the run from mapped spi flash working
CPU_FREQ=45
FPGA_VARIANT=hx1k
FPGA_PACKAGE=tq144
VERILOGS=$1
yosys -q -DICE4PI -DICE_STICK -DBOARD_FREQ=$BOARD_FREQ -DCPU_FREQ=$CPU_FREQ -p "synth_ice40 -relut -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
nextpnr-ice40 --force --timing-allow-fail --json $PROJECTNAME.json --pcf BOARDS/$BOARD.pcf --asc $PROJECTNAME.asc --freq $CPU_FREQ --$FPGA_VARIANT --package $FPGA_PACKAGE --pcf-allow-unconstrained --opt-timing || exit
icetime -p BOARDS/$BOARD.pcf -P $FPGA_PACKAGE -r $PROJECTNAME.timings -d $FPGA_VARIANT -t $PROJECTNAME.asc
#add -s flag to icepack options to keep flash awake
icepack -s $PROJECTNAME.asc $PROJECTNAME.bin || exit
#icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
#iceprog $PROJECTNAME.bin || exit
echo "run upload tool from pi with ice4pi pcb on board"
echo "if pi5 is host apparently you have to dance around enabling and disabling spi from sudo raspi-config"
cp $PROJECTNAME.bin ../../../../mnt
echo DONE.

