include ../makefile.inc

all:
	Echo please specify target

clean:
	rm -f *.o *.elf *.hex *rawhex *.exe

%.elf: %.o
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld $< -o $@ -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)
