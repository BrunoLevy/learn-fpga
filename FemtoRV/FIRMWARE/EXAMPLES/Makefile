include ../makefile.inc 

ALL_PROGRAMS=\
commander.exe cube_OLED.exe demo_OLED.exe hello.exe imgui_cup.exe\
imgui_doom.exe imgui_road.exe imgui_tunnel.exe life_led_matrix.exe\
mandelbrot_float_OLED.exe mandelbrot_OLED.exe riscv_logo_OLED.exe\
sieve.exe spirograph_OLED.exe ST_NICCC.exe ST_NICCC_spi_flash.exe\
sysconfig.exe test_buttons.exe test_font_OLED.exe test_OLED.exe\
test_spi_flash.exe test_spi_sdcard.exe tinyraytracer.exe tty_OLED.exe

all:
	@echo "Please specify target (progname.exe or progname.hex) or 'everything'"

everything: $(ALL_PROGRAMS)

%.elf: %.o $(RV_BINARIES)
	$(RVLD) $(RVLDFLAGS) -T$(FIRMWARE_DIR)/femtorv32.ld $< -o $@ -L$(FIRMWARE_DIR)/CRT_BAREMETAL -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)
#	$(RVGCC) -ffreestanding -Wl,--gc-sections -nostartfiles -nostdlib -nodefaultlibs $(RVCFLAGS) -Wl,-T,$(FIRMWARE_DIR)/CRT_BAREMETAL/baremetal.ld $(FIRMWARE_DIR)/CRT_BAREMETAL/crt0.o $< -o $@ -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc
#	$(RVGCC) $(RVCFLAGS) -Wl,-T,$(FIRMWARE_DIR)/CRT_BAREMETAL/baremetal.ld -L$(FIRMWARE_DIR)/CRT_BAREMETAL $< -o $@ -L$(FIRMWARE_DIR)/LIBFEMTORV32 -L$(FIRMWARE_DIR)/LIBFEMTOC -lfemtorv32 -lfemtoc
# I would like to link with gcc, but this does not work for now (my linker script is probably broken, many things that I do not understand there ...)
