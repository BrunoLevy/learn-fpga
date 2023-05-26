PROJECTNAME=serial
VERILOGS="$PROJECTNAME.v uart.v"
yosys -q -p "synth_ice40 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit
nextpnr-ice40 --json $PROJECTNAME.json --pcf $PROJECTNAME.pcf --asc $PROJECTNAME.asc --freq 12 --hx1k --package tq144 || exit
icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
iceprog $PROJECTNAME.bin || exit
echo DONE.




