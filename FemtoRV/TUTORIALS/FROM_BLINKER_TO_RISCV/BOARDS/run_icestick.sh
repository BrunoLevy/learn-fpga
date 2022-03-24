PROJECTNAME=SOC
BOARD=icestick
VERILOGS=$1
yosys -q -DICE_STICK -p "synth_ice40 -relut -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
nextpnr-ice40 --force --json $PROJECTNAME.json --pcf BOARDS/$BOARD.pcf --asc $PROJECTNAME.asc --freq 12 --hx1k --package tq144 --pcf-allow-unconstrained || exit
icetime -p BOARDS/$BOARD.pcf -P tq144 -r $PROJECTNAME.timings -d hx1k -t $PROJECTNAME.asc
icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
iceprog $PROJECTNAME.bin || exit
echo DONE.




