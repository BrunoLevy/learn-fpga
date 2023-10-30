(cd obj_dir; rm -f *.cpp *.o *.a VSOC)
verilator -CFLAGS '-I../../../FIRMWARE/LIBFEMTORV32 -DSTANDALONE_FEMTOELF' -DBENCH -DBOARD_FREQ=10 -DCPU_FREQ=10 -DPASSTHROUGH_PLL -Wno-fatal \
	  --top-module SOC -cc -exe sim_main.cpp ../../FIRMWARE/LIBFEMTORV32/femto_elf.c $1
(cd obj_dir; make -f VSOC.mk)
obj_dir/VSOC $2

