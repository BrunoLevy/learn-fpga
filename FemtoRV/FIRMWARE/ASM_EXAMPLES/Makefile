include ../makefile.inc

ALL_PROGRAMS=\
blinker_shift.bin blinker_wait.bin hello.bin\
mandelbrot_OLED.bin mandelbrot_terminal.bin\
test_led_matrix.bin test_OLED.bin test_serial.bin

all:
	@echo "Please specify target (progname.bin or progname.hex) or 'everything'"

everything: $(ALL_PROGRAMS)


# Generate a "bare metal elf", to be loaded from address 0 (rule for conversion to .hex file in makefile.inc)
%.bm_elf: %.o $(RV_BINARIES)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/femtorv32.ld $< -o $@ -L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

# Generate a "femtOS elf executable", to be loaded from address 0x10000 (rule for conversion to .bin file in makefile.inc)
# (note: does not work for now for assembly programs, I do not know why, to be debugged)
#%.elf: %.o $(RV_BINARIES)
#	$(RVGCC) $(RVCFLAGS) $< -o $@ -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc -lm
