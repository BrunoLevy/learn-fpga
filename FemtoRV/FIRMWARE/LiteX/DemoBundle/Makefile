# usage:
# 1) make BUILD_DIR=<the directory where you generated the SOC>
#   (for instance, LiteX/build/radiona_ulx3s)
#   Alternatively you can edit this file and change LITEX_DIR and
#   LITEX_PLATFORM below.
# 2) lxterm /dev/ttyUSBnnn --kernel demo.bin
# 3) litex> reboot
#
# Started from litex/litex/soc/software/demo/Makefile
# My changes indicated by [BL] tags.

# [BL] I'm used to 'make VERBOSE=1' to see commands
# (and LiteX uses 'make V=1' for this). Makes both work.
V?=$(VERBOSE)

# [BL] find BUILD_DIR without using Python wrapper
LITEX_DIR?=/home/blevy/Programming/LiteX
LITEX_PLATFORM?=radiona_ulx3s
BUILD_DIR?=$(LITEX_DIR)/build/$(LITEX_PLATFORM)

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

# [BL] replace LiteX-provided libcompiler_rt (that misses
# some functions, e.g. floating-point) with libgcc (that has everything)
LIBS:=$(LIBS:libcompiler_rt=libgcc)

# [BL] optimize for speed ! (I *LOVE* speed !!!)
COMMONFLAGS:=$(COMMONFLAGS:-Os=-O3)
CFLAGS:=$(CFLAGS:-Os=-O3)
CXXFLAGS:=$(CXXFLAGS:-Os=-O3)

# [BL] no debug info (prevents some optimizations)
COMMONFLAGS:=$(COMMONFLAGS:-g3=)
CFLAGS:=$(CFLAGS:-g3=)
CXXFLAGS:=$(CXXFLAGS:-g3=)

# [BL] use builtins (except for printf)
COMMONFLAGS:=$(COMMONFLAGS:-fno-builtin=-fno-builtin-printf)
CFLAGS:=$(CFLAGS:-fno-builtin=-fno-builtin-printf)
CXXFLAGS:=$(CXXFLAGS:-fno-builtin=-fno-builtin-printf)

# [BL] no exceptions
COMMONFLAGS:=$(COMMONFLAGS:-fexceptions=)
CFLAGS:=$(CFLAGS:-fexceptions=)
CXXFLAGS:=$(CXXFLAGS:-fexceptions=)

OBJECTS   = isr.o main.o lite_oled.o tinyraytracer.o pi.o oled_test.o oled_riscv_logo.o oled_julia.o crt0.o

all: demo.bin

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

# [BL] added rule to examine generated assembly (make demo.list)
# Rem: $(OBJDUMP) not defined, so "deducing" it from $(OBJCOPY) (substituting)
%.list: %.elf
	$(OBJCOPY:objcopy=objdump) -Mnumeric -D $< > $@

demo.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		$(LIBS:lib%=-l%)
	chmod -x $@

main.o: main.c
	$(compile)

# [BL] made crt0.o dependent on one of the generated files to make sure it
# is recompiled whenever configuration is changed (for instance, when
# swapping femtorv variants)
crt0.o: $(CPU_DIRECTORY)/crt0.S $(BUILD_DIR)/software/include/generated/variables.mak
	$(assemble)

donut.o: CFLAGS += -w

helloc.o: CFLAGS += -w

%.o: %.cpp
	$(compilexx)

%.o: %.c
	$(compile)

%.o: %.S
	$(assemble)

clean:
	$(RM) $(OBJECTS) $(OBJECTS:.o=.d) demo.elf demo.bin demo.list .*~ *~

terminal:
	lxterm --kernel demo.bin /dev/ttyUSB0; reset
	
.PHONY: all main.o clean load
