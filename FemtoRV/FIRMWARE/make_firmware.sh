# Compile lib
(cd LIB; ./makeit.sh)

# Compile program that post-processes hex file
(cd TOOLS; ./makeit.sh)

# Compile firmware program (assembly or C)
rm -f BUILD/firmware.o
if [[ $1 == *.s ]]
then
  riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o BUILD/firmware.o $1
else
   if [[ $1 == *.c ]] 
   then
      echo "C compile"
      # This line so that we can examine produced assembly
      riscv64-linux-gnu-gcc-10 -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -S $1 -o BUILD/firmware.s
      riscv64-linux-gnu-gcc-10 -O3 -fno-pic -march=rv32i -mabi=ilp32 -ILIB -c -o BUILD/firmware.o $1
   else
      echo "Invalid firmware source file:" $1
      echo "Specify one of the firmware source files in EXAMPLES (asm) or C_EXAMPLES (C)"
      echo "Note: some examples may require a different hardware configuration and options in picosoc.v"
      exit
   fi
fi

# Link
# Note: seems that LIB/crt0.o is linked automatically (it is good, but I do not know why...)
riscv64-linux-gnu-ld -m elf32lriscv_ilp32 -b elf32-littleriscv -Tcontrol.ld -o BUILD/firmware.elf BUILD/firmware.o -LLIB -lfemtorv32
# Dump hexadecimal content
riscv64-linux-gnu-objcopy -O verilog BUILD/firmware.elf BUILD/firmware.objcopy.hex
# Adapt hexadecimal content (32 bit words instead of individual bytes)
(cd BUILD; rm firmware.hex; ../TOOLS/firmware_words)
cp BUILD/firmware.hex .

## Display assembly
#riscv64-linux-gnu-objcopy -O binary BUILD/firmware.elf BUILD/firmware.bin
#riscv64-linux-gnu-objdump -D -b binary -m riscv BUILD/firmware.bin 

#echo Firmware size: `cat BUILD/firmware.hex | wc -w` words


