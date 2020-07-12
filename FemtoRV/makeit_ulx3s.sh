PROJECTNAME=femtosoc
VERILOGS="$PROJECTNAME.v"
echo ======== Firmware
if [ -e FIRMWARE/firmware.hex ]
then
    (cd FIRMWARE/BUILD; rm firmware.hex; ../TOOLS/firmware_words; cp firmware.hex ../)    
else    
    echo "Missing FIRMWARE/firmware.hex"
    echo "Using default (FIRMWARE/EXAMPLES/mandelbrot_terminal.s)"
    echo "To replace, cd FIRMWARE; ./make_firmware.sh EXAMPLES/....   or C_EXAMPLES/...."
    (cd FIRMWARE; ./make_firmware.sh EXAMPLES/mandelbrot_terminal.s)
fi
echo ======== Yosys
yosys -DULX3S -q -p "synth_ecp5 -abc9 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit

echo ======== NextPNR
nextpnr-ecp5 --force --json $PROJECTNAME.json --lpf ulx3s.lpf --textcfg $PROJECTNAME_out.config --85k --freq 25 --package CABGA381 $1 || exit

echo ======== ecppack
ecppack --svf-rowsize 100000 --svf $PROJECTNAME.svf $PROJECTNAME_out.config $PROJECTNAME.bit

echo ======== ujprog
ujprog $PROJECTNAME.bit
#ujprog -j FLASH $PROJECTNAME.bit

echo DONE.


