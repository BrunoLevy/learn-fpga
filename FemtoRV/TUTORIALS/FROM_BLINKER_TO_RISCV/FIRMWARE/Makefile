include ../../../FIRMWARE/makefile.inc
RVASFLAGS=-march=$(ARCH) -mabi=$(ABI)
RVCFLAGS=-I. -O2 -fno-pic -march=$(ARCH) -mabi=$(ABI) -fno-stack-protector -w -Wl,--no-relax

RAM_SIZE=6144

LIBOBJECTS=putchar.o wait.o print.o memcpy.o errno.o perf.o

%.bram.elf: %.o start.o $(LIBOBJECTS) $(RV_BINARIES)
	$(RVLD) -T bram.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a -o $@


%.hex: %.elf $(FIRMWARE_DIR)/TOOLS/firmware_words
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -ram $(RAM_SIZE) -max_addr $(RAM_SIZE) -out $@
	cp $@ ../firmware.hex
	mkdir -p ../obj_dir
	cp $@ ../obj_dir/firmware.hex
	echo $@ > ../firmware.txt

# SPI link map partial solution, needs improvement
# Run what are now .ld templates through precrocessor
# TODO cleanup gen_spiflash?.ld when `make clean` is issued
# TODO see about converting to one rule instead of specific rules
gen_spiflash0.ld: spiflash0.ld link_memory_info.h
	echo "/* $(BOARD) */" > gen_spiflash0.ld
	$(RVGCC) $(DEVICES) -E -CC -P -x c spiflash0.ld >>gen_spiflash0.ld

gen_spiflash1.ld: spiflash1.ld link_memory_info.h
	echo "/* $(BOARD) */" > gen_spiflash1.ld
	$(RVGCC) $(DEVICES) -E -P -x c spiflash1.ld >>gen_spiflash1.ld

gen_spiflash2.ld: spiflash2.ld link_memory_info.h
	echo "/* $(BOARD) */" > gen_spiflash2.ld
	$(RVGCC) $(DEVICES) -E -P -x c spiflash2.ld >>gen_spiflash2.ld

# SPI FLASH 0 (sends everything to SPI flash)


%.spiflash0.elf: %.o start.o $(LIBOBJECTS) $(RV_BINARIES) gen_spiflash0.ld
	$(RVLD) -T gen_spiflash0.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a -o $@

%.spiflash0.bin: %.spiflash0.elf
	$(RVOBJCOPY) $< $@ -O binary

%.spiflash0.prog: %.spiflash0.bin
	$(TOOLCHAIN_PROG_CMD)
	#iceprog -o 128k $<

# SPI FLASH 1 (sends code and variables initialization to SPI flash, variables to RAM)

%.spiflash1.elf: %.o start_spiflash1.o $(LIBOBJECTS) $(RV_BINARIES) gen_spiflash1.ld
	$(RVLD) -T gen_spiflash1.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a -o $@


%.spiflash1.bin: %.spiflash1.elf
	$(RVOBJCOPY) $< $@ -O binary

%.spiflash1.prog: %.spiflash1.bin
	$(TOOLCHAIN_PROG_CMD)
	#iceprog -o 128k $<


# SPI FLASH 2 (sends code and variables initialization to SPI flash, variables and fastcode to RAM)

%.spiflash2.elf: %.o start_spiflash1.o $(LIBOBJECTS) $(RV_BINARIES) gen_spiflash2.ld
	$(RVLD) -T gen_spiflash2.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) -L$(RVTOOLCHAIN_LIB_DIR) -lm  $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a -o $@


%.spiflash2.bin: %.spiflash2.elf
	$(RVOBJCOPY) $< $@ -O binary

%.spiflash2.prog: %.spiflash2.bin
	$(TOOLCHAIN_PROG_CMD)
	#iceprog -o 128k $<

%.spiflash2.list: %.spiflash2.elf
	$(RVOBJDUMP) -Mnumeric -D $< > $@

# DUAL MEMORY (64 kb program ROM, 64 kb data RAM)

%.pipeline.elf: %.o start_pipeline.o $(LIBOBJECTS) $(RV_BINARIES)
	$(RVLD) -T pipeline.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) -L$(RVTOOLCHAIN_LIB_DIR) -lm $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a  -o $@
	$(RVOBJDUMP) -Mnumeric -D $@ > $@.list

%.PROGROM.hex: %.pipeline.elf $(FIRMWARE_DIR)/TOOLS/firmware_words
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -ram 0x20000 -max_addr 0x20000 -out $@ -from_addr 0 -to_addr 0xFFFF
	cp $@ ../PROGROM.hex
	mkdir -p ../obj_dir
	cp $@ ../obj_dir/PROGROM.hex

%.DATARAM.hex: %.pipeline.elf $(FIRMWARE_DIR)/TOOLS/firmware_words
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -ram 0x20000 -max_addr 0x20000 -out $@ -from_addr 0x10000 -to_addr 0x1FFFF
	cp $@ ../DATARAM.hex
	mkdir -p ../obj_dir
	cp $@ ../obj_dir/DATARAM.hex

%.pipeline.hex: %.PROGROM.hex %.DATARAM.hex
	echo $@ > ../firmware.txt

