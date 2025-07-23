ARCH = rv32i
ABI = ilp32
RVASFLAGS= -march=$(ARCH) -mabi=$(ABI) 
RVCFLAGS= $(RVINCS) -fno-pic -march=$(ARCH) -mabi=$(ABI) \
         -fno-stack-protector -w -Wl,--no-relax
RVINCS=-I ./LIBFEMTOGL -I ./LIBFEMTORV32 -I ./LIBFEMTOC
RAM_SIZE=6144

LIBOBJECTS=putchar.o wait.o print.o memcpy.o errno.o perf.o

RVAS= riscv64-unknown-elf-as
RVLD= riscv64-unknown-elf-ld
RVOBJCOPY= riscv64-unknown-elf-objcopy
RVOBJDUMP= riscv64-unknown-elf-objdump
RVGCC= riscv64-unknown-elf-gcc
RVGPP= riscv64-unknown-elf-g++
RVAR= riscv64-unknown-elf-ar
RVRANLIB= riscv64-unknown-elf-ranlib

# RV_BINARIES=$(RVAS) $(RVLD) $(RVOBJCOPY) $(RVOBJDUMP) $(RVGCC) \
#             $(RVAR) $(RVRANLIB)

.c.o: $< 
	$(RVGCC) $(RVCFLAGS) $(RVUSERCFLAGS) -c $<

# #Rule to compile ASM objects
.S.o: $<
	$(RVAS) $(RVASFLAGS) $< -o $@ 

%.bram.elf: %.o start.o $(LIBOBJECTS) 
	$(RVLD) -T bram.ld -m elf32lriscv -nostdlib $< $(LIBOBJECTS) ./libgcc.a -o $@


%.hex: %.elf 
	./firmware_words $< -ram $(RAM_SIZE) -max_addr $(RAM_SIZE) -out $@
	cp $@ ../RTL/firmware.hex
	mkdir -p ../RTL/obj_dir
	cp $@ ../RTL/obj_dir/firmware.hex
	echo $@ > ../RTL/firmware.txt

clean:
	rm *.bram.hex