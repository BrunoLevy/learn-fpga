include ../makefile.inc

all:
	@echo "Please specify target (progname.exe or progname.hex)"

%.elf: %.o
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld $< -o $@ -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

