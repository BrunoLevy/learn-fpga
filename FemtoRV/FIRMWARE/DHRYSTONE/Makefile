include ../makefile.inc

RVUSERCFLAGS=-w -DRISCV -DTIME -DUSE_MYSTDLIB -fno-pic
OBJECTS=dhry_1.o dhry_2.o stubs.o

all: dhrystone.exe

dhrystone.elf: $(OBJECTS)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/femtorv32.ld -o $@  $(OBJECTS) -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -L$(FIRMWARE_DIR)/CRT_BAREMETAL -lfemtorv32 -lfemtoc $(RVGCC_LIB)

