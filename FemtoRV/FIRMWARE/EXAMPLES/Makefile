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

%.elf: %.o
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld $< -o $@ -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

