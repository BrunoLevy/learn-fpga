(cd ../LIB; ./makeit.sh)
riscv64-linux-gnu-gcc-10 -w -DRISCV -DTIME -DUSE_MYSTDLIB -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c dhry_1.c
riscv64-linux-gnu-gcc-10 -w -DRISCV -DTIME -DUSE_MYSTDLIB -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c dhry_2.c
riscv64-linux-gnu-gcc-10 -w -DRISCV -DTIME -DUSE_MYSTDLIB -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c stubs.c

riscv64-linux-gnu-gcc-10 -S -w -DRISCV -DTIME -DUSE_MYSTDLIB -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c dhry_1.c
riscv64-linux-gnu-gcc-10 -S -w -DRISCV -DTIME -DUSE_MYSTDLIB -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c dhry_2.c


# Link
# Note: seems that LIB/crt0.o is linked automatically (it is good, but I do not know why...)
riscv64-linux-gnu-ld -m elf32lriscv_ilp32 -b elf32-littleriscv -Tfemtorv32.ld -o firmware.elf dhry_1.o dhry_2.o stubs.o -L../LIB -lfemtorv32

riscv64-linux-gnu-objcopy -O verilog firmware.elf firmware.objcopy.hex
cp firmware.objcopy.hex ../BUILD/


