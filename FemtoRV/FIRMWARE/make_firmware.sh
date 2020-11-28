mkdir -p BUILD

echo "============> Compiling tools"
(cd TOOLS;        ./makeit.sh)      # Compile program that post-processes hex file
echo "============> Compiling libs"
(cd LIBFEMTORV32; make clean libfemtorv32.a > /dev/null) # Compile hardware support lib
(cd LIBFEMTOC;    make clean libfemtoc.a    > /dev/null) # Compile lib with printf() replacement function
# Note: I 'make clean' each time, because there is no much to recompile (and dependencies
# are not specified)...
EXE_BASENAME=`basename $1 | sed -e 's|\.c$||' -e 's|\.S$||'`
SOURCE_DIR=`dirname $1`
echo "============>" Making $EXE_BASENAME
(cd $SOURCE_DIR; make clean $EXE_BASENAME".rawhex")
echo "============>" Packing firmware

# Adapt hexadecimal content (32 bit words instead of individual bytes)
cp $SOURCE_DIR"/"$EXE_BASENAME".rawhex" BUILD/firmware.rawhex
(cd BUILD; rm firmware.hex; ../TOOLS/firmware_words)
cp BUILD/firmware.hex .

# Display message with ARCH,ABI,OPTIMIZE (useful to know at that point)
ARCH=`grep < makefile.inc '^ARCH='`
ABI=`grep < makefile.inc '^ABI='`
OPTIMIZE=`grep < makefile.inc '^OPTIMIZE='`
echo "Generated firmware (arch=$ARCH, abi=$ABI, optimize=$OPTIMIZE)"

## Display assembly
#$RVOBJCOPY -O binary BUILD/firmware.elf BUILD/firmware.bin
#$RVOBJDUMP -D -b binary -m riscv BUILD/firmware.bin 
