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
LIB_OBJECTS=lite_oled.o lite_fb.o lite_elf.o\
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
	lxterm --kernel boot.bin /dev/ttyUSB0; reset
	
.PHONY: all everything clean load

BIOS_SRC_DIR=$(LITEX_DIR)/litex/litex/soc/software/bios

%.o: $(BIOS_SRC_DIR)/%.c
	$(compile)

%.o: $(BIOS_SRC_DIR)/cmds/%.c
	$(compile)
