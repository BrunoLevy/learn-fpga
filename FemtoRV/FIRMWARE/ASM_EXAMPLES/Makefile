include ../makefile.inc

ALL_PROGRAMS=\
blinker_shift.exe blinker_wait.exe hello.exe\
mandelbrot_OLED.exe mandelbrot_terminal.exe\
test_led_matrix.exe test_OLED.exe test_serial.exe

all:
	@echo "Please specify target (progname.exe or progname.hex) or 'everything'"

everything: $(ALL_PROGRAMS)


%.elf: %.o
	$(RVLD) $(RVLDFLAGS) -T../femtorv32.ld $< -o $@ -L../LIBFEMTORV32 -L../LIBFEMTOC -lfemtorv32 -lfemtoc $(RVGCC_LIB)

