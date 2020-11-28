PROJECTNAME=femtosoc
VERILOGS="$PROJECTNAME.v"
echo ======== Firmware
if [ -e FIRMWARE/firmware.hex ]
then
    echo "Using existing FIRMWARE/firmware.hex image"
else    
    echo "Missing FIRMWARE/firmware.hex"
    echo "Using FemtOS image (needs OLED screen) (FIRMWARE/EXAMPLES/commander.exe)"
    echo "To replace, cd FIRMWARE; ./make_firmware.sh EXAMPLES/...."
    (cd FIRMWARE; ./make_firmware.sh EXAMPLES/commander.exe)
fi
echo ======== Yosys
yosys -DULX3S -q -p "synth_ecp5 -abc9 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit

echo ======== NextPNR
nextpnr-ecp5 --force --timing-allow-fail --json $PROJECTNAME.json --lpf ulx3s.lpf --textcfg $PROJECTNAME_out.config --85k --freq 25 --package CABGA381 $1 || exit

echo ======== ecppack
ecppack --compress --svf-rowsize 100000 --svf $PROJECTNAME.svf $PROJECTNAME_out.config $PROJECTNAME.bit

echo ======== ujprog
ujprog $PROJECTNAME.bit
#ujprog -j FLASH $PROJECTNAME.bit

echo DONE.


