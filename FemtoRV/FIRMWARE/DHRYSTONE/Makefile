include ../makefile.inc

RVUSERCFLAGS=-w -DRISCV -DTIME -DUSE_MYSTDLIB -fno-pic
OBJECTS=dhry_1.o dhry_2.o stubs.o

all: dhrystone.bin

# Generate a "femtOS elf executable", to be loaded from address 0x10000 (rule for conversion to .bin file in makefile.inc)
dhrystone.elf: $(OBJECTS)
	$(RVGCC) $(RVCFLAGS) $(OBJECTS) -o $@ -L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc -lm

