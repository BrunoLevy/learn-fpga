################################################################################
#   testbench pseudo-board
################################################################################

BENCH: BENCH.verilator

BENCH.firmware_config:
	BOARD=testbench TOOLS/make_config.sh -DBENCH
	(cd FIRMWARE; make libs)

BENCH.icarus:
	(cd RTL; iverilog -IPROCESSOR -IDEVICES femtosoc_bench.v \
         -o ../femtosoc_bench.vvp)
	vvp femtosoc_bench.vvp


BENCH.verilator:
	verilator -DBENCH --top-module femtoRV32_bench \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL  \
	 -LDFLAGS '-lglfw -lGL' \
	 --cc --exe SIM/sim_main.cpp RTL/femtosoc_bench.v
	(cd obj_dir; make -f VfemtoRV32_bench.mk)	 
	obj_dir/VfemtoRV32_bench

BENCH.lint:
	verilator -DBENCH --lint-only --top-module femtoRV32_bench \
         -IRTL -IRTL/PROCESSOR -IRTL/DEVICES -IRTL/PLL femtosoc_bench.v
################################################################################
