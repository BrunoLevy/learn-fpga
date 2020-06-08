PROGNAME=firmware

# Assemble
riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o $PROGNAME.o $PROGNAME.s
# Link
riscv64-linux-gnu-ld -m elf32lriscv_ilp32 -b elf32-littleriscv -Ttext 0 -o $PROGNAME.elf $PROGNAME.o
# Dump hexadecimal content
riscv64-linux-gnu-objcopy -O verilog $PROGNAME.elf $PROGNAME.objcopy.hex
# Adapt hexadecimal content (32 bit words instead of individual bytes)
./firmware_words

## Display assembly
riscv64-linux-gnu-objcopy -O binary $PROGNAME.elf $PROGNAME.bin
riscv64-linux-gnu-objdump -D -b binary -m riscv $PROGNAME.bin 

echo ROM size: `cat $PROGNAME.hex | wc -w` words


