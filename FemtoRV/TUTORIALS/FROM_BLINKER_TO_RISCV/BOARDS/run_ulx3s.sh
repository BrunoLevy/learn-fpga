PROJECTNAME=SOC
BOARD=ulx3s
BOARD_FREQ=25
FPGA_VARIANT=85k
FPGA_PACKAGE=CABGA381
VERILOGS=$1

yosys -q -DBOARD_FREQ=$BOARD_FREQ -p "synth_ecp5 -abc9 -top $PROJECTNAME -json $PROJECTNAME.json" $VERILOGS  || exit
nextpnr-ecp5 --force --timing-allow-fail --json $PROJECTNAME.json --lpf BOARDS/$BOARD.lpf --textcfg $PROJECTNAME"_out".config --freq $BOARD_FREQ --$FPGA_VARIANT --package $FPGA_PACKAGE || exit
ecppack --compress --svf-rowsize 100000 --svf $PROJECTNAME".svf" $PROJECTNAME"_out.config" $PROJECTNAME".bit" || exit
ujprog -j FLASH $PROJECTNAME".bit"  || exit

