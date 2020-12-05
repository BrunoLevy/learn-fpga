# Configuration file for femtoRV32 firmware compilation
# Specify directories, toolchain and target architecture

# Base directory of the firmware
FIRMWARE_DIR=/home/blevy/Programming/learn-fpga/FemtoRV/FIRMWARE

# Configuration for larger boards (ULX3S, ECP5-EVN)
#ARCH=rv32im
#ABI=ilp32
#OPTIMIZE=-O3

# More minimalistic configurations (ICEStick, ICE40)
# note: ICE40up5K could support rv32im but this requires some work
#  since yosys does not (yet) infer DSP blocks for ICE40).
ARCH=rv32i
ABI=ilp32
OPTIMIZE=-Os
# Optimize for size, on the IceStick we only have 6K of RAM !

# Normally you do not need to modify anything beyond this line.
############################################################################################################

# Website to get the RISCV toolchain
TOOLCHAIN_WEB=https://static.dev.sifive.com/dev-tools

# Version of the RISCV toolchain to get
#TOOLCHAIN_VER=riscv64-unknown-elf-gcc-20171231-x86_64-linux-centos6
#TOOLCHAIN_GCC_VER=7.2.0
TOOLCHAIN_VER=riscv64-unknown-elf-gcc-8.3.0-2020.04.0-x86_64-linux-ubuntu14
TOOLCHAIN_GCC_VER=8.3.0

RVTOOLCHAIN_DIR=$(FIRMWARE_DIR)/TOOLCHAIN/$(TOOLCHAIN_VER)
RVTOOLCHAIN_BIN_DIR=$(RVTOOLCHAIN_DIR)/bin
RVTOOLCHAIN_LIB_DIR=$(RVTOOLCHAIN_DIR)/riscv64-unknown-elf/lib/$(ARCH)/ilp32
RVTOOLCHAIN_GCC_LIB_DIR=$(RVTOOLCHAIN_DIR)/lib/gcc/riscv64-unknown-elf/$(TOOLCHAIN_GCC_VER)/$(ARCH)/ilp32
RVTOOLCHAIN_BIN_PREFIX=riscv64-unknown-elf

RVAS=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-as
RVLD=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-ld
RVOBJCOPY=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-objcopy
RVOBJDUMP=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-objdump
RVGCC=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-gcc
RVAR=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-ar
RVRANLIB=$(RVTOOLCHAIN_BIN_DIR)/$(RVTOOLCHAIN_BIN_PREFIX)-ranlib

RV_BINARIES=$(RVAS) $(RVLD) $(RVOBJCOPY) $(RVOBJDUMP) $(RVGCC) $(RVAR) $(RVRANLIB)

# Note: it is also possible to comment this line, and use replacement functions
# for a small subset of libc, see comments in LIBFEMTOC/Makefile. 
RVGCC_LIB= $(RVTOOLCHAIN_LIB_DIR)/libc.a $(RVTOOLCHAIN_LIB_DIR)/libm.a $(RVTOOLCHAIN_GCC_LIB_DIR)/libgcc.a

# My utility that converts hex files into a format understood by Verilog
FIRMWARE_WORDS=$(FIRMWARE_DIR)/TOOLS/firmware_words

############################################################################################################

RVINCS=-I$(FIRMWARE_DIR)/LIBFEMTORV32 -I$(FIRMWARE_DIR)/LIBFEMTOC
RVCFLAGS=$(OPTIMIZE) $(RVINCS) -fno-pic -march=$(ARCH) -mabi=$(ABI) -fno-stack-protector -w
RVASFLAGS=-march=$(ARCH) -mabi=$(ABI) $(RVINCS)
RVLDFLAGS=-m elf32lriscv -b elf32-littleriscv

#Rule to compile C objects
.c.o: $< $(RV_BINARIES)
	$(RVGCC) $(RVCFLAGS) $(RVUSERCFLAGS) -c $<

#Rule to compile ASM objects
.S.o: $< $(RV_BINARIES)
	$(RVAS) $(RVASFLAGS) $(RVUSERASFLAGS) $< -o $@ 

#Rule to convert an ELF binary into a raw hex file (that cannot be directly imported in verilog files)
%.rawhex: %.elf $(RV_BINARIES)
	$(RVOBJCOPY) -O verilog $< $@
	
#Rule to convert a raw hex file into an hex file that can be directly imported in verilog files
%.hex: %.rawhex $(FIRMWARE_DIR)/TOOLS/firmware_words
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -verilog $(FIRMWARE_DIR)/../femtosoc.v -hex $@
#	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -ram 262144 -hex $@

#Rule to convert a raw hex file into an executable (flat binary file)
%.exe: %.rawhex $(FIRMWARE_DIR)/TOOLS/firmware_words
	$(FIRMWARE_DIR)/TOOLS/firmware_words $< -verilog $(FIRMWARE_DIR)/../femtosoc.v -exe $@

.PHONY: root clean all get_riscv_toolchain

root: all

clean:
	rm -f *.o *.elf *.hex *rawhex *.exe *~

#Generating the conversion utility for hex files	
$(FIRMWARE_DIR)/TOOLS/firmware_words: $(FIRMWARE_DIR)/TOOLS/FIRMWARE_WORDS/firmware_words.cpp
	g++ $< -o $@

##############################################################################################
#RISCV toolchain, get it from the web, automatically

$(RVAS):
	make get_riscv_toolchain

$(RVLD):
	make get_riscv_toolchain

$(RVOBJCOPY):
	make get_riscv_toolchain

$(RVOBJDUMP):
	make get_riscv_toolchain

$(RVGCC):
	make get_riscv_toolchain

$(RVAR):
	make get_riscv_toolchain

$(RVRANLIB):
	make get_riscv_toolchain

get_riscv_toolchain:
	mkdir -p $(FIRMWARE_DIR)/TOOLCHAIN
	@echo "Downloading and installing RISC-V toolchain in $(FIRMWARE_DIR)/TOOLCHAIN"
	(cd $(FIRMWARE_DIR)/TOOLCHAIN; \
	    wget $(TOOLCHAIN_WEB)/$(TOOLCHAIN_VER).tar.gz; \
	    tar xfz $(TOOLCHAIN_VER).tar.gz)
