YOSYS_ECP5_EVN_OPT=-DECP5_EVN -q -p "synth_ecp5 -top $(PROJECTNAME) -json $(PROJECTNAME).json"
NEXTPNR_ECP5_EVN_OPT=--force --json $(PROJECTNAME).json --lpf BOARDS/ecp5_evn.lpf \
                     --textcfg $(PROJECTNAME)_out.config --um5g-85k --freq 50 --package CABGA381

#######################################################################################################################

ECP5_EVN:ECP5_EVN.synth ECP5_EVN.prog

ECP5_EVN.synth: FIRMWARE/firmware.hex 
	TOOLS/make_config.sh -DECP5_EVN
	yosys $(YOSYS_ECP5_EVN_OPT) $(VERILOGS)
	nextpnr-ecp5 $(NEXTPNR_ECP5_EVN_OPT)
	ecppack --compress --svf-rowsize 100000 --svf $(PROJECTNAME).svf $(PROJECTNAME)_out.config $(PROJECTNAME).bit

ECP5_EVN.prog:
	ujprog $(PROJECTNAME).bit           
#	openocd -f BOARDS/ecp5-evn.cfg -c "transport select jtag; init; svf $(PROJECTNAME).svf; exit"

ECP5_EVN.prog_flash:
	ujprog -j flash $(PROJECTNAME).bit           

