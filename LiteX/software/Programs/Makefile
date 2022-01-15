include ../makefile.inc

all: hello.elf tinyraytracer.elf spirograph.elf ST_NICCC.elf imgui_test.elf 

%.elf: %.o libliteos.a crt0.o sbrk.o
	$(CC) ./crt0.o $< sbrk.o $(LDFLAGS) \
		-T linker.ld \
		-N -o $@ \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-L. -lliteos $(LIBS:lib%=-l%) -lbase 
	chmod -x $@

