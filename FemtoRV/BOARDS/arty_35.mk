ARTY: ARTY.firmware_config ARTY.synth ARTY.prog

ARTY.synth:
	mkdir -p build/arty_35
	cd build/arty_35 && ln -sf ../../RTL .
	cd build/arty_35 && ln -sf ../../BOARDS .
	cd build/arty_35 && ln -sf ../../FIRMWARE .	
	cd build/arty_35 && symbiflow_synth -t $(PROJECTNAME) -v BOARDS/arty_defs.v $(VERILOGS) -d artix7 -p xc7a35tcsg324-1 -x BOARDS/arty.xdc 2>&1 > /dev/null
	cd build/arty_35 && symbiflow_pack  -e $(PROJECTNAME).eblif -d xc7a50t_test 2>&1 > /dev/null
	cd build/arty_35 && symbiflow_place -e $(PROJECTNAME).eblif -d xc7a50t_test -n $(PROJECTNAME).net -P xc7a35tcsg324-1 2>&1 > /dev/null
	cd build/arty_35 && symbiflow_route -e $(PROJECTNAME).eblif -d xc7a50t_test 2>&1 > /dev/null
	cd build/arty_35 && symbiflow_write_fasm -e $(PROJECTNAME).eblif -d xc7a50t_test 
	cd build/arty_35 && symbiflow_write_bitstream symbiflow_write_bitstream -d artix7 -f $(PROJECTNAME).fasm -p xc7a35tcsg324-1 -b $(PROJECTNAME).bit

ARTY.prog:
	cd build/arty_35 && openocd -f $(HOME)/opt/symbiflow/xc7/conda/envs/xc7/share/openocd/scripts/board/digilent_arty.cfg -c "transport select jtag; init; pld load 0 $(PROJECTNAME).bit; exit"

ARTY.firmware_config:
	BOARD=arty TOOLS/make_config.sh -DARTY
	(cd FIRMWARE; make libs)
