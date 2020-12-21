include ../makefile.inc 

ALL_PROGRAMS=\
commander.bin cube_OLED.bin demo_OLED.bin hello.bin imgui_cup.bin\
imgui_doom.bin imgui_road.bin imgui_tunnel.bin life_led_matrix.bin\
mandelbrot_float_OLED.bin mandelbrot_OLED.bin riscv_logo_OLED.bin\
sieve.bin spirograph_OLED.bin ST_NICCC.bin ST_NICCC_spi_flash.bin\
sysconfig.bin test_buttons.bin test_font_OLED.bin test_OLED.bin\
test_spi_flash.bin test_spi_sdcard.bin tinyraytracer.bin tty_OLED.bin

all:
	@echo "Please specify target (progname.bin or progname.hex) or 'everything'"

everything: $(ALL_PROGRAMS)

# Generate a "bare metal elf", to be loaded from address 0 (rule for conversion to .hex file in makefile.inc)
%.bm_elf: %.o $(RV_BINARIES)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/femtorv32.ld $< -o $@ \
	-L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC \
	-lfemtorv32 -lfemtoc $(RVGCC_LIB)

# Generate a "femtOS elf executable", to be loaded from address 0x10000 (rule for conversion to .bin file in makefile.inc)
%.elf: %.o $(RV_BINARIES)
	$(RVGCC) $(RVCFLAGS) $< -o $@ -Wl,-gc-sections \
	-L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC \
	-lfemtorv32 -lfemtoc -lm

