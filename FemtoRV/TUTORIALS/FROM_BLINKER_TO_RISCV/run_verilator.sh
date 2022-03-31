verilator -DBENCH -DBOARD_FREQ=12 -Wno-fatal --top-module SOC -cc -exe sim_main.cpp $1
(cd obj_dir; rm -f *.o *.a VSOC; make -f VSOC.mk; ./VSOC)

