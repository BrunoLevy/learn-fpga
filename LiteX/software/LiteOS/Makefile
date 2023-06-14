# usage:
# 1) make BUILD_DIR=<the directory where you generated the SOC>
#   (for instance, LiteX/build/radiona_ulx3s)
#   Alternatively you can edit this file and change LITEX_DIR and
#   LITEX_PLATFORM below.
# 2) lxterm /dev/ttyUSBnnn --kernel boot.bin
# 3) litex> reboot

include ../makefile.inc

# These ones are compiled from the sources in LiteX/litex/litex/soc/software/bios/
BIOS_OBJECTS=complete.o helpers.o readline.o cmd_bios.o
OBJECTS = $(BIOS_OBJECTS) builtins.o isr.o main.o crt0.o

all: boot.bin

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

boot.elf: $(OBJECTS) libliteos.a
	$(CC) $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		$(LIBS:lib%=-l%) -L. -lliteos 
	chmod -x $@

# Made crt0.o dependent on one of the generated files to make sure it
# is recompiled whenever configuration is changed (for instance, when
# swapping femtorv variants)
crt0.o: $(CPU_DIRECTORY)/crt0.S $(BUILD_DIR)/software/include/generated/variables.mak
	$(assemble)

