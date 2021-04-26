PROJECTNAME=HDMI_test_hires
#PROJECTNAME=HDMI_test
#PROJECTNAME=HDMI_test_DDR # This one uses DDR primitives for higher freq, ready for higher res (to be tested)
VERILOGS="$PROJECTNAME.v HDMI_clock.v TMDS_encoder.v"

if [ $1 == "clean" ]; then
  rm -f *.bit *.json *.config *.svf *~
  exit
fi

yosys -p "synth_ecp5 -abc9 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS || exit
nextpnr-ecp5 --json $PROJECTNAME.json --lpf ulx3s.lpf --textcfg $PROJECTNAME.config --85k --freq 25 --package CABGA381 || exit
ecppack --compress --svf-rowsize 100000 --svf $PROJECTNAME.svf $PROJECTNAME.config $PROJECTNAME.bit || exit
ujprog $PROJECTNAME.bit || exit
# To flash permanently, use instead:
#   Use ujprog -j FLASH $PROJECTNAME.bit 