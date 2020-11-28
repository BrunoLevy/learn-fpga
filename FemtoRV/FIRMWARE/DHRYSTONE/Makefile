include ../makefile.inc

RVUSERCFLAGS=-w -DRISCV -DTIME -DUSE_MYSTDLIB -fno-pic
OBJECTS=dhry_1.o dhry_2.o stubs.o

all: dhrystone.exe

dhrystone.elf: $(OBJECTS)
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld -o $@  $(OBJECTS) -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

