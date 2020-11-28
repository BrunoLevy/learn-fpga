all:
	@echo "Please specify target (progname.exe or progname.hex)"

# Needs to be *after* first target (else it will build firmware_words) and *before* linker rule (else RVLDFLAGS is not defined)
include ../makefile.inc

%.elf: %.o
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld $< -o $@ -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

