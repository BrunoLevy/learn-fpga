. ./config.sh

mkdir -p BUILD

# Compile lib
(cd LIBFEMTORV32; ./makeit.sh)

# Compile lib
(cd LIBFEMTOC; ./makeit.sh)

# Compile program that post-processes hex file
(cd TOOLS; ./makeit.sh)

# Compile firmware program (assembly or C)
rm -f BUILD/firmware.o
if [[ $1 == *.S ]]
then
  echo "asm compile: " $1 
  $RVAS -march=$ARCH -mabi=$ABI -o BUILD/firmware.o $1
else
   if [[ $1 == *.c ]] 
   then
      echo "C compile: " $1
      # This line so that we can examine produced assembly
      $RVGCC $OPTIMIZE -fno-pic -march=$ARCH -mabi=$ABI -ILIBFEMTORV32 -ILIBFEMTOC -S $1 -fno-stack-protector -o BUILD/firmware.s
      $RVGCC $OPTIMIZE -fno-pic -march=$ARCH -mabi=$ABI -ILIBFEMTORV32 -ILIBFEMTOC -c -fno-stack-protector -o BUILD/firmware.o $1
   else
      echo "Invalid firmware source file:" $1
      echo "Specify one of the firmware source files in EXAMPLES (asm) or C_EXAMPLES (C)"
      echo "Note: some examples may require a different hardware configuration and options in picosoc.v"
      exit
   fi
fi

# Link
# Note: seems that LIB/crt0.o is linked automatically (it is good, but I do not know why...)
#$RVLD -m elf32lriscv_ilp32 -b elf32-littleriscv -Tfemtorv32.ld -o BUILD/firmware.elf BUILD/firmware.o -LLIB -lfemtorv32
$RVLD -m elf32lriscv -b elf32-littleriscv -Tfemtorv32.ld -o BUILD/firmware.elf BUILD/firmware.o -LLIBFEMTORV32 -LLIBFEMTOC -lfemtorv32 -lfemtoc $ADDITIONAL_LIB
# Dump hexadecimal content
$RVOBJCOPY -O verilog BUILD/firmware.elf BUILD/firmware.objcopy.hex
# Adapt hexadecimal content (32 bit words instead of individual bytes)
(cd BUILD; rm firmware.hex; ../TOOLS/firmware_words)
cp BUILD/firmware.hex .

echo "Generated firmware (arch=$ARCH, abi=$ABI, optimize=$OPTIMIZE)"

## Display assembly
#$RVOBJCOPY -O binary BUILD/firmware.elf BUILD/firmware.bin
#$RVOBJDUMP -D -b binary -m riscv BUILD/firmware.bin 
