PROJECTNAME=femtosoc
VERILOGS="$PROJECTNAME.v"
echo ======== Firmware
#(cd FIRMWARE; ./make_firmware.sh C_EXAMPLES/test_print_hex.c)
if [ ! -e FIRMWARE/firmware.hex ]
then
    echo "Missing FIRMWARE/firmware.hex"
    echo "Using FIRMWARE/EXAMPLES/mandelbrot_terminal.s"
    (cd FIRMWARE; ./make_firmware.sh EXAMPLES/mandelbrot_terminal.s)
fi
echo Firmware size: `cat FIRMWARE/firmware.hex | wc -w` words
echo ======== Yosys
yosys -DICE_STICK -q -p "ice40_braminit" -p "synth_ice40 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit
echo ======== NextPNR
nextpnr-ice40 --force --json $PROJECTNAME.json --pcf $PROJECTNAME.pcf --asc $PROJECTNAME.asc --freq 12 --hx1k --package tq144 $1 || exit
echo ======== IceTime
icetime -p $PROJECTNAME.pcf -P tq144 -r $PROJECTNAME.timings -d hx1k -t $PROJECTNAME.asc
echo ======== IcePack
#-s to disable SPI flash sleep
icepack $PROJECTNAME.asc $PROJECTNAME.bin || exit
echo ======== IceProg
iceprog $PROJECTNAME.bin || exit
echo DONE.


