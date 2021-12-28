# usage:
# 1) make BUILD_DIR=<the directory where you generated the SOC>
#   (for instance, LiteX/build/radiona_ulx3s)
#   Alternatively you can edit this file and change LITEX_DIR and
#   LITEX_PLATFORM below.
# 2) lxterm /dev/ttyUSBnnn --kernel boot.bin
# 3) litex> reboot

# I'm used to 'make VERBOSE=1' to see commands
# (and LiteX uses 'make V=1' for this). Makes both work.
V?=$(VERBOSE)

# find BUILD_DIR without using Python wrapper
LITEX_DIR?=/home/blevy/Programming/LiteX
LITEX_PLATFORM?=radiona_ulx3s
BUILD_DIR?=$(LITEX_DIR)/build/$(LITEX_PLATFORM)

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

BIOS_SRC_DIR=$(LITEX_DIR)/litex/litex/soc/software/bios

# replace LiteX-provided libcompiler_rt (that misses
# some functions, e.g. floating-point) with libgcc (that has everything)
LIBS:=$(LIBS:libcompiler_rt=libgcc)

# Include path 
CFLAGS:=$(CFLAGS) -I../Libs -Iframework -I$(BIOS_SRC_DIR)
CXXFLAGS:=$(CXXFLAGS) -Ilibs -Iframework -I$(BIOS_SRC_DIR)

# optimize for speed ! (I *LOVE* speed !!!)
COMMONFLAGS:=$(COMMONFLAGS:-Os=-O3)
CFLAGS:=$(CFLAGS:-Os=-O3)
CXXFLAGS:=$(CXXFLAGS:-Os=-O3)

# no debug info (prevents some optimizations)
COMMONFLAGS:=$(COMMONFLAGS:-g3=)
CFLAGS:=$(CFLAGS:-g3=)
CXXFLAGS:=$(CXXFLAGS:-g3=)

# use builtins (except for printf)
COMMONFLAGS:=$(COMMONFLAGS:-fno-builtin=-fno-builtin-printf)
CFLAGS:=$(CFLAGS:-fno-builtin=-fno-builtin-printf)
CXXFLAGS:=$(CXXFLAGS:-fno-builtin=-fno-builtin-printf)

# no exceptions
COMMONFLAGS:=$(COMMONFLAGS:-fexceptions=)
CFLAGS:=$(CFLAGS:-fexceptions=)
CXXFLAGS:=$(CXXFLAGS:-fexceptions=)

# Compiled from the sources in libs/
LIB_OBJECTS=lite_oled.o lite_fb.o lite_elf.o

# These ones are compiled from the sources in LiteX/litex/litex/soc/software/bios/
BIOS_OBJECTS=complete.o helpers.o readline.o cmd_bios.o

OBJECTS = $(BIOS_OBJECTS) builtins.o isr.o main.o crt0.o

all: boot.bin

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

# added rule to examine generated assembly (make boot.list)
# Rem: $(OBJDUMP) not defined, so "deducing" it from $(OBJCOPY) (substituting)
%.list: %.elf
	$(OBJCOPY:objcopy=objdump) -Mnumeric -D $< > $@

boot.elf: $(OBJECTS) libliteos.a
	$(CC) $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		$(LIBS:lib%=-l%) -L. -lliteos
	chmod -x $@

libliteos.a: $(LIB_OBJECTS)
	ar cq libliteos.a $(LIB_OBJECTS)
	ranlib libliteos.a

main.o: main.c
	$(compile)

# Made crt0.o dependent on one of the generated files to make sure it
# is recompiled whenever configuration is changed (for instance, when
# swapping femtorv variants)
crt0.o: $(CPU_DIRECTORY)/crt0.S $(BUILD_DIR)/software/include/generated/variables.mak
	$(assemble)

%.o: %.cpp
	$(compilexx)

%.o: %.c
	$(compile)

%.o: ../Libs/%.c
	$(compile)

%.o: $(BIOS_SRC_DIR)/%.c
	$(compile)

%.o: $(BIOS_SRC_DIR)/cmds/%.c
	$(compile)

%.o: %.S
	$(assemble)

clean:
	$(RM) $(OBJECTS) $(OBJECTS:.o=.d) $(LIB_OBJECTS) $(LIB_OBJECTS:.o=.d) boot.elf boot.bin boot.list libliteos.a .*~ *~

terminal:
	lxterm --kernel boot.bin /dev/ttyUSB0; reset
	
.PHONY: all clean load
