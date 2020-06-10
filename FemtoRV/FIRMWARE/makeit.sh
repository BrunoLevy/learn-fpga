# Compile lib
(cd LIB; ./makeit.sh)

# Compile program that post-processes hex file
(cd TOOLS; ./makeit.sh)

# Assemble
riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o BUILD/firmware.o firmware.s
# Link
riscv64-linux-gnu-ld -m elf32lriscv_ilp32 -b elf32-littleriscv -Ttext 0 -o BUILD/firmware.elf LIB/femtorv32.o BUILD/firmware.o
# Dump hexadecimal content
riscv64-linux-gnu-objcopy -O verilog BUILD/firmware.elf BUILD/firmware.objcopy.hex
# Adapt hexadecimal content (32 bit words instead of individual bytes)
(cd BUILD; ../TOOLS/firmware_words)
cp BUILD/firmware.hex .

## Display assembly
riscv64-linux-gnu-objcopy -O binary BUILD/firmware.elf BUILD/firmware.bin
riscv64-linux-gnu-objdump -D -b binary -m riscv BUILD/firmware.bin 

echo ROM size: `cat BUILD/firmware.hex | wc -w` words


