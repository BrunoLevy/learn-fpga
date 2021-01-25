include ../makefile.inc 

# Generate a "femtOS elf executable", to be loaded from address 0x10000 
%.elf: %.cpp syscalls.o $(RV_BINARIES)
	$(RVGPP) $(RVCFLAGS) $(RVCPPFLAGS) -nostdlib $< syscalls.o -o $@ -Wl,-gc-sections \
          -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC \
	  -lfemtorv32 -lfemtoc -lm -lsupc++ $(RVGCC_LIB) $(FIRMWARE_DIR)/CRT_BAREMETAL/crt0.o

