# I'm used to 'make VERBOSE=1' to see commands
# (and LiteX uses 'make V=1' for this). Makes both work.
V?=$(VERBOSE)

# Change the following three variables according to your
# local installation (or use LITEX_DIR=... LEARN_FPGA_DIR=...
# LITEX_PLATFORM=... on the command line)
LITEX_DIR?=/home/blevy/Programming/LiteX
LEARN_FPGA_DIR?=/home/blevy/Programming/learn-fpga
LITEX_PLATFORM?=radiona_ulx3s

BUILD_DIR?=$(LEARN_FPGA_DIR)/LiteX/build/$(LITEX_PLATFORM)

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

BIOS_SRC_DIR=$(LITEX_DIR)/litex/litex/soc/software/bios

# replace LiteX-provided libcompiler_rt (that misses
# some functions, e.g. floating-point) with libgcc (that has everything)
LIBS:=$(LIBS:libcompiler_rt=libgcc)

# add libbase, that has memspeed and memtest
LIBS += -lbase 

# Remove the 2p0_ 2p0 string from riscV instr set
# definition from LDFLAGS, else it does not find the
# right libgcc 
LDFLAGS:=`echo $(LDFLAGS) | sed -E 's|2p0(_)?||'`

# Include path 
CFLAGS:=$(CFLAGS) -I../Libs  -I$(BIOS_SRC_DIR)
CXXFLAGS:=$(CXXFLAGS) -I../Libs -I../Libs/imgui -I$(BIOS_SRC_DIR) -fno-threadsafe-statics -fno-rtti 

# optimize for speed ! (I *LOVE* speed !!!)
COMMONFLAGS:=$(COMMONFLAGS:-Os=-O3)
CFLAGS:=$(CFLAGS:-Os=-O3)
CXXFLAGS:=$(CXXFLAGS:-Os=-O3)

# no debug info (prevents some optimizations)
COMMONFLAGS:=$(COMMONFLAGS:-g3=)
CFLAGS:=$(CFLAGS:-g3=)
CXXFLAGS:=$(CXXFLAGS:-g3=)

# use builtins (except for printf and malloc)
COMMONFLAGS:=$(COMMONFLAGS:-fno-builtin=-fno-builtin-printf)
CFLAGS:=$(CFLAGS:-fno-builtin=-fno-builtin-printf -fno-builtin-malloc)
CXXFLAGS:=$(CXXFLAGS:-fno-builtin=-fno-builtin-printf -fno-builtin-malloc)

# no exceptions
COMMONFLAGS:=$(COMMONFLAGS:-fexceptions=)
CFLAGS:=$(CFLAGS:-fexceptions=-fno-exceptions)
CXXFLAGS:=$(CXXFLAGS:-fexceptions=-fno-exceptions)

# Compiled from the sources in libs/
LIB_OBJECTS=lite_oled.o lite_fb.o lite_elf.o lite_stdio.o\
            imgui.o imgui_demo.o imgui_draw.o imgui_tables.o imgui_widgets.o imgui_sw.o 

# added rule to examine generated assembly (make boot.list)
# Rem: $(OBJDUMP) not defined, so "deducing" it from $(OBJCOPY) (substituting)
%.list: %.elf
	$(OBJCOPY:objcopy=objdump) -Mnumeric -D $< > $@

everything: all

libliteos.a: $(LIB_OBJECTS)
	ar cq libliteos.a $(LIB_OBJECTS)
	ranlib libliteos.a

%.o: %.cpp
	$(compilexx)

%.o: %.c
	$(compile)

%.o: ../Libs/%.c
	$(compile)

%.o: ../Libs/imgui/%.cpp
	$(compilexx)

%.o: $(BIOS_SRC_DIR)/%.c
	$(compile)

%.o: $(BIOS_SRC_DIR)/cmds/%.c
	$(compile)

%.o: %.S
	$(assemble)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

clean:
	$(RM) *.d *.o *.a *.elf *.list .*~ *~

terminal:
	litex_term --kernel boot.bin /dev/ttyUSB0; reset
	
.PHONY: all everything clean load

BIOS_SRC_DIR=$(LITEX_DIR)/litex/litex/soc/software/bios

%.o: $(BIOS_SRC_DIR)/%.c
	$(compile)

%.o: $(BIOS_SRC_DIR)/cmds/%.c
	$(compile)
