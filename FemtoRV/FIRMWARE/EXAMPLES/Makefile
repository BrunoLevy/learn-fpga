include ../makefile.inc 

ALL_PROGRAMS=\
commander.elf cube_OLED.elf demo_OLED.elf hello.elf imgui_cup.elf\
imgui_doom.elf imgui_road.elf imgui_tunnel.elf life_led_matrix.elf\
mandelbrot_float_OLED.elf mandelbrot_OLED.elf riscv_logo_OLED.elf\
sieve.elf spirograph_OLED.elf ST_NICCC.elf ST_NICCC_spi_flash.elf\
sysconfig.elf test_buttons.elf test_font_OLED.elf test_OLED.elf\
test_spi_flash.elf test_spi_sdcard.elf tinyraytracer.elf tty_OLED.elf\
test_FGA.elf 

all:
	@echo "Please specify target (progname.elf or progname.bin) or 'everything'"

everything: $(ALL_PROGRAMS)

# Generate a "bare metal elf", to be loaded from address 0 (rule for conversion to .hex file in makefile.inc)
%.bm_elf: %.o $(RV_BINARIES)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/CRT_BAREMETAL/femtorv32.ld $< -o $@ \
	-L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC \
	-lfemtorv32 -lfemtoc $(RVGCC_LIB)

# Generate a "femtOS elf executable", to be loaded from address 0x10000 (rule for conversion to .bin file in makefile.inc)
%.elf: %.o $(RV_BINARIES)
	$(RVGCC) $(RVCFLAGS) $< -o $@ -Wl,-gc-sections \
	-L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc -lm
