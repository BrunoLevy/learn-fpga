PARTNAME=xc7a35tcsg324-1
DEVICE=xc7a50t_test
BITSTREAM_DEVICE=artix7

ARTY: ARTY.firmware_config ARTY.synth ARTY.prog

ARTY.synth:
	echo logging to build/arty_35/log.txt
	mkdir -p build/arty_35
	cd build/arty_35 && ln -sf ../../RTL .
	cd build/arty_35 && ln -sf ../../BOARDS .
	cd build/arty_35 && ln -sf ../../FIRMWARE .	
	cd build/arty_35 && symbiflow_synth -t $(PROJECTNAME) -v BOARDS/arty_defs.v $(VERILOGS) -d $(BITSTREAM_DEVICE) -p $(PARTNAME) \
                                            -x BOARDS/arty.xdc 2>&1 > log.txt
	cd build/arty_35 && symbiflow_pack  -e $(PROJECTNAME).eblif -d $(DEVICE) 2>&1 >> log.txt
	cd build/arty_35 && symbiflow_place -e $(PROJECTNAME).eblif -d $(DEVICE) -n $(PROJECTNAME).net -P $(PARTNAME) 2>&1 >> log.txt
	cd build/arty_35 && symbiflow_route -e $(PROJECTNAME).eblif -d $(DEVICE) 2>&1 >> log.txt
	cd build/arty_35 && symbiflow_write_fasm -e $(PROJECTNAME).eblif -d $(DEVICE) 2>&1 >> log.txt
	cd build/arty_35 && symbiflow_write_bitstream -dsp -d $(BITSTREAM_DEVICE) -f $(PROJECTNAME).fasm -p $(PARTNAME) -b $(PROJECTNAME).bit 2>&1 >> log.txt

ARTY.prog_fast:
	openFPGALoader --board arty build/arty_35/femtosoc.bit
# Alternative if you do not have openFPGALoader installed	
#	cd build/arty_35 && openocd -f $(HOME)/opt/symbiflow/xc7/conda/envs/xc7/share/openocd/scripts/board/digilent_arty.cfg -c "transport select jtag; init; pld load 0 $(PROJECTNAME).bit; exit"

ARTY.prog:
	openFPGALoader --board arty -f build/arty_35/femtosoc.bit


ARTY.firmware_config:
	BOARD=arty TOOLS/make_config.sh -DARTY
	(cd FIRMWARE; make libs)
