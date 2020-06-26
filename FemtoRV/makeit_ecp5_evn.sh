PROJECTNAME=femtosoc
VERILOGS="$PROJECTNAME.v"
echo ======== Firmware
if [ -e FIRMWARE/firmware.hex ]
then
    (cd FIRMWARE/BUILD; rm firmware.hex; ../TOOLS/firmware_words)    
else    
    echo "Missing FIRMWARE/firmware.hex"
    echo "Using default (FIRMWARE/EXAMPLES/mandelbrot_terminal.s)"
    echo "To replace, cd FIRMWARE; ./make_firmware.sh EXAMPLES/....   or C_EXAMPLES/...."
    (cd FIRMWARE; ./make_firmware.sh EXAMPLES/mandelbrot_terminal.s)
fi
echo ======== Yosys
yosys -DECP5_EVN -q -p "synth_ecp5 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit

echo ======== NextPNR
nextpnr-ecp5 --force --json $PROJECTNAME.json --lpf $PROJECTNAME.lpf --textcfg $PROJECTNAME_out.config --um5g-85k --freq 50 --package CABGA381 $1 || exit

echo ======== ecppack
ecppack --svf-rowsize 100000 --svf $PROJECTNAME.svf $PROJECTNAME_out.config $PROJECTNAME.bit

echo ======== openocd
openocd -f ecp5-evn.cfg -c "transport select jtag; init; svf $PROJECTNAME.svf; exit"

echo DONE.


