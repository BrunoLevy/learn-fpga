RVUSERCFLAGS=-w -DRISCV -DTIME -DUSE_MYSTDLIB -fno-pic
OBJECTS=dhry_1.o dhry_2.o stubs.o

all: dhrystone.exe

# Needs to be *after* first target (else it will build firmware_words) and *before* linker rule (else RVLDFLAGS is not defined)
include ../makefile.inc

dhrystone.elf: $(OBJECTS)
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld -o $@  $(OBJECTS) -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

