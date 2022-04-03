include ../../../FIRMWARE/makefile.inc
RVASFLAGS=-march=$(ARCH) -mabi=$(ABI) 
RVCFLAGS=-Os -fno-pic -march=$(ARCH) -mabi=$(ABI) -fno-stack-protector -w -Wl,--no-relax 

RAMSIZE=6144

LIBOBJECTS=putchar.o wait.o print.o

%.bram.elf: %.o start.o $(LIBOBJECTS) $(RV_BINARIES)
	$(RVLD) -T bram.ld -m elf32lriscv -nostdlib -norelax $< $(LIBOBJECTS) $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a -o $@

%.hex: %.elf $(FIRMWARE_DIR)/TOOLS/firmware_words 
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -ram $(RAM_SIZE) -max_addr 65535 -hex $@
	cp $@ ../firmware.hex
	mkdir -p ../obj_dir
	cp $@ ../obj_dir/firmware.hex
	echo $@ > ../firmware.txt

