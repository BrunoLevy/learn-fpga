include ../makefile.inc 

everything: cpp_test.elf tinyrt_cpp.elf

# Generate a "femtOS elf executable", to be loaded from address 0x10000 
#%.elf: %.o $(RV_BINARIES)
#	$(RVGPP) $(RVCFLAGS) $(RVCPPFLAGS) -nostdlib $< -o $@ -Wl,-gc-sections \
#	$(FEMTORV32_LIBS) -lsupc++ $(RVGCC_LIB) $(FIRMWARE_DIR)/CRT_BAREMETAL/crt0.o


