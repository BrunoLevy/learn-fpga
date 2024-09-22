PROJECTNAME=SOC
BOARD=icezero
BOARD_FREQ=100
#CPU_FREQ=45
#20 works
#CPU_FREQ=20
#35 for step24.v to be inside timing requirements
#CPU_FREQ=35
#go back to default to see if it gets the run from mapped spi flash working
CPU_FREQ=35
MIN_FREQ=12
FPGA_VARIANT=hx8k
FPGA_PACKAGE=tq144:4k
VERILOGS=$1
yosys -q -DICE_ZERO -DBOARD_FREQ=$BOARD_FREQ -DCPU_FREQ=$CPU_FREQ -p "synth_ice40 -relut -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
nextpnr-ice40 --force --timing-allow-fail --json $PROJECTNAME.json --pcf BOARDS/$BOARD.pcf --asc $PROJECTNAME.asc --freq $MIN_FREQ --$FPGA_VARIANT --package $FPGA_PACKAGE --pcf-allow-unconstrained --opt-timing || exit
icetime -p BOARDS/$BOARD.pcf -P $FPGA_PACKAGE -r $PROJECTNAME.timings -d $FPGA_VARIANT -t $PROJECTNAME.asc
#add -s flag to icepack options to keep flash awake
icepack -s $PROJECTNAME.asc $PROJECTNAME.bin || exit
#icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
#iceprog $PROJECTNAME.bin || exit
echo "run upload tool from pi with icezero pcb on board"
ABSPATH=$(cd -- "../../../../mnt/trenz/TUTORIAL/" && pwd -P)
echo "copying duplicate files "$ABSPATH"/SOC_"$VERILOGS".bin for convenience and SOC.bin in keeping with documentation"
cp $PROJECTNAME.bin $ABSPATH"/SOC_"$VERILOGS".bin"
cp $PROJECTNAME.bin $ABSPATH"/SOC.bin"
echo DONE.

