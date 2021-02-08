include ../makefile.inc

all:
	@echo "Please specify target (progname.bm_elf or progname.hex) or 'everything'"

everything: $(ALL_PROGRAMS)


# Generate a "spi elf", to be loaded from address 0x810000 
%.spi_elf: %.o $(RV_BINARIES) 
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/CRT/spiflash.ld $< -o $@ \
	-L$(FIRMWARE_DIR)/CRT \
        -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB) 

%.bin: %.spi_elf
	$(RVOBJDUMP) -Mnumeric -D $< > tmp.list
	$(RVOBJCOPY) $< $@ -O binary

%.prog: %.bin
	iceprog -o 64k $<

